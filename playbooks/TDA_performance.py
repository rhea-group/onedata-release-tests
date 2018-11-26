#!/usr/bin/python

import paramiko
import os
import logging
import sys
import time
import subprocess
import json

from argparse import ArgumentParser

from timeit import default_timer as timer

privatekeyfile = './id_rsa'

def remoteCommand(ssh, str, verbose=False):
    stdin, stdout, stderr = ssh.exec_command(str, 600)
    stdin.close()
    for line in iter(lambda: stdout.readline(2048), ""):
        if verbose:
            print(line.encode('utf-8')),
            sys.stdout.flush()
    for line in iter(lambda: stderr.readline(2048), ""):
        if verbose:
            print(line.encode('utf-8')),
            sys.stdout.flush()
    return stdout.channel.recv_exit_status()


def waitFile(site, file, status, ssh, filesize=0):
     t = 0
     timeout = 400
     start = timer()
     logging.info('Waiting for file {}'.format(file))
     while True:
#         executeCommand(site, "ls -la " + os.path.dirname(file), ssh)
         res, elapsed = executeCommand(site, "ls -la " + file, ssh)
         if res == 0 and status == "exists":
             logging.info('File {} found: '.format(file))
             logging.info('Waiting for size to be {}'.format(str(abs(filesize))))
             while True:
                 res, elapsed = executeCommand(site,
                                               "ls -l --block-size=1 " + file + "| awk '{ print $5 }' | grep " + str(
                                                   abs(filesize)), ssh)
                 if res == 0:
                     break
                 else:
                     logging.info('Size still not {} - waiting 5 seconds'.format(str(abs(filesize))))
                     time.sleep(5) # bkryza: Increased from 3
                     t = t + 1
                     if t > timeout:
                         sys.exit("Wait file status failed " + file)
             break
         elif res != 0 and status == "not exists":
             logging.info('File {} doesn\'t exist: '.format(file))
             break
         else:
             time.sleep(5) # bkryza: Increased from 3
             logging.info('File {} not found - waiting 5 seconds: '.format(file))
             t = t + 1
             if t > timeout:
                 logging.info('File {} not found - timeout exceeded: '.format(file))
                 sys.exit("Wait file status failed " + file)
     end = timer()
     return end - start


def executeCommand(site, command, ssh, verbose=False):
    if verbose:
        print site, command
        sys.stdout.flush()

    logging.info('Executing command {}: {}'.format(site, command))
    if ">" not in command and not verbose:
        command += " >/dev/null 2>&1"
    start = timer()
    if site == "L":
        stat = os.system(command)
    elif site == "R":
        stat = remoteCommand(ssh, command, verbose)
    end = timer()
    return stat, end - start


def createFileCommand(dir, fname, size):
    logging.info('Creating empty file {} using dd of size {}'.format(fname, str(size)))
    if size > 0:
        return "dd if=/dev/zero of=" + fname + " iflag=count_bytes count=" + str(size)
    #        return "/usr/sbin/xfs_mkfile "+ str(size) + fname

    fdir = os.path.dirname(fname)
    basename = os.path.basename(fname)
    suf = os.path.splitext(basename)[0]
    image_name = ""
    if size == -99971392:
        image_name = "yakser/h5sim_small"
    elif size == -999696128:
        image_name = "yakser/h5sim_med"
    elif size == -9996937344:
        image_name = "yakser/h5sim"
    return "sudo docker run -u `id -u`:`id -g` -v " + fdir + ":/data " + image_name + " run_write " + \
           basename + " > " + fdir + "/out_write_" + suf + "_" + dir


def readFileCommand(dir, fname, size, attempt):
    logging.info('Reading from file using cat {} > /dev/null'.format(fname))
    if size > 0:
        return "cat " + fname + " >/dev/null"

    fdir = os.path.dirname(fname)
    basename = os.path.basename(fname)
    suf = os.path.splitext(basename)[0]

    if size == -99971392:
        image_name = "yakser/h5sim_small"
    elif size == -999696128:
        image_name = "yakser/h5sim_med"
    elif size == -9996937344:
        image_name = "yakser/h5sim"

    return "sudo docker run -u `id -u`:`id -g` -v " + fdir + ":/data " + image_name + " run_read " +\
           basename + " > " + fdir + "/out_read_" + suf + "_" + dir + "_" + str(attempt)

def getFileSize(args):
    if args.size == "small":
        size = 99971392
    elif args.size == "medium":
        size = 999696128
    elif args.size == "large":
        size = 9996937344
    if args.mode == "h5sim":
        size = -size
    return size

def start(args):
    print "starting"
    logging.info("Starting TDA")
    sys.stdout.flush()

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # mykey = paramiko.RSAKey.from_private_key_file(args.rsaKeyFile)

    #ssh.connect(args.ip, username=args.user, pkey=mykey)
    ssh.connect(args.ip, username=args.user)
    print "paramiko ssh: connected"
    sys.stdout.flush()

    resname = {'L': 'local', 'R': 'remote'}

    fname = {}
    fname["L"] = args.localDir + "/" + args.fileName
    fname["R"] = args.remoteDir + "/" + args.fileName

    if args.direction == "local-remote":
        dir="LR"
    else:
        dir = "RL"

    fileSize = getFileSize(args)
    timeVis = 0
    if args.createFiles:
        print "File created " + resname[dir[0]] + "ly in:",
        sys.stdout.flush()
        elapsed = executeCommand(dir[0], createFileCommand(dir[0], fname[dir[0]], fileSize), ssh)[1]
        print "%.2f s" % (elapsed)
        sys.stdout.flush()
        print createFileCommand(dir[0], fname[dir[0]], fileSize)
        sys.stdout.flush()
        # executeCommand(dir[0], "ls -l "+fname[dir[0]], ssh, True)
        # executeCommand(dir[0], "md5sum "+fname[dir[0]], ssh, True)
        print "File visible " + resname[dir[1]] + "ly after:",
        sys.stdout.flush()
        timeVis = waitFile(dir[1], fname[dir[1]], "exists", ssh, fileSize)
    # if dir == "RL":
        # timeVis += utils.waitTransferRequestsFinished(fname[dir[1]], 600)
        print "%.2f s" % timeVis
        print "-" * 80
        sys.stdout.flush()
    if dir[0] == 'R' and args.waitForReplication == "true":
        # Wait for replication to complete
        logging.info("Waiting for replication...")
        sys.stdout.flush()
        command = 'curl --tlsv1.2 "https://'+args.providerFQDN+'/configuration"'
        output=subprocess.check_output(command, stderr=open('err.log', 'a'), shell=True)
        data = json.loads(output)
        providerId=data['providerId']
        head, filename = os.path.split(fname["R"])
        command = 'curl --tlsv1.2 -X GET -H "X-Auth-Token: '+args.accessToken+'" "https://'+args.providerFQDN+'/api/v3/oneprovider/replicas/'+args.spacePath+'/'+filename+'"'
        logging.info("Getting replicas using: {}".format(command))
        print command
        sys.stdout.flush()
        a = "1"
        b = "2"
        not_in_posix_provider_only=True
        while a != b and not_in_posix_provider_only:
            time.sleep(5)
            output=subprocess.check_output(command, stderr=open('err.log', 'a'), shell=True)
            data = json.loads(output)
            logging.info("Got file replicas: {}".format(output))

            #print "len=%d" % (len(data))
            #sys.stdout.flush()
            if len(data) == 2:
                #print "in the if"
                a = data[0]["blocks"]
                b = data[1]["blocks"]
                for i in range(len(data)):
                    if data[i]['providerId'] == providerId:
                        providerIndex=i
                        break
                if len(data[providerIndex]['blocks']) == 1 and len(data[(providerIndex+1) % 2]['blocks']) == 0:
                    not_in_posix_provider_only = False
            if len(data) == 1 and data[0]['providerId'] == providerId:
                not_in_posix_provider_only = False
                
            logging.info("Blocks a={}, b={}".format(str(a), str(b)))
            #print "a=" + a + "  b=" + b
            #sys.stdout.flush()
            

    realSize = os.path.getsize(fname["L"])
    realSize_MB = realSize / 1024 / 1024

    print "Access file " + resname[dir[1]] + "ly:",
    sys.stdout.flush()
    epoch_time_start = time.time()
    st, timeAccess = executeCommand(dir[1], readFileCommand(dir[1], fname[dir[1]], fileSize, 1), ssh, args.verbose)
    epoch_time_end = time.time()
    print st
    print "%.2f s, BW: %d Mb/s, BW_Eff: %d Mb/s, %.2f , %.2f" % (
    timeAccess, int(realSize_MB / float(timeAccess) * 8), int(realSize_MB / float(timeAccess + timeVis) * 8),
    epoch_time_start,epoch_time_end)
    sys.stdout.flush()
    if args.removeAfterwards:
        print "Remove file " + resname[dir[1]] + "ly in:",
        sys.stdout.flush()        
        st, elapsed = executeCommand(dir[1], "rm -rf " + fname[dir[1]], ssh)
        print "%.2f s" % (elapsed)
        print "status of rm: %d" % (st)
        sys.stdout.flush()
        print "File dissapears " + resname[dir[0]] + "ly after:",
        print "%.2f s" % waitFile(dir[0], fname[dir[0]], "not exists", ssh)
        sys.stdout.flush()


if __name__ == "__main__":
    print "main"

    parser = ArgumentParser()

    parser.add_argument("--access-token", dest="accessToken",required=True)
    parser.add_argument("--provider-fqdn", dest="providerFQDN",required=True)
    parser.add_argument("--space-path", dest="spacePath",required=True)
    parser.add_argument("--wait-for-replication", dest="waitForReplication",required=False,default=True)
    parser.add_argument("--remote-address", dest="ip",required=True)
    parser.add_argument("--local-dir", dest="localDir",required=True,
                        help="local directory")
    parser.add_argument("--remote-dir", dest="remoteDir",required=True,
                        help="local directory")
    parser.add_argument("--size", dest="size",required=True, choices=['small', 'medium', 'large'])
    parser.add_argument("--writeread-mode", dest="mode", required=True, choices=['h5sim', 'system'])
    parser.add_argument("--user", dest="user",required=True,
                        help="remote user name")
    parser.add_argument("--file-name", dest="fileName",required=True)
    parser.add_argument("--rsa-key-file", dest="rsaKeyFile",required=True,
                        help="path to the rsa key to access a remote machine")
    parser.add_argument('--remove-afterwards', dest = "removeAfterwards",default=False, type=lambda x: (str(x).lower() == 'true'))
    parser.add_argument('--create-files',dest="createFiles", default=True, type=lambda x: (str(x).lower() == 'true'))
    parser.add_argument("--direction", dest="direction",required=True, choices=['local-remote', 'remote-local'])
    parser.add_argument('--verbose', dest = "verbose",default=False, type=lambda x: (str(x).lower() == 'true'))


    args = parser.parse_args()

    logging.basicConfig(
        filename="/tmp/TDA_performance_{}_{}.log".format(args.fileName, os.getpid()),
        level=logging.DEBUG)

    logging.info("Initialized logging...")

    verbose = False
    print "=" * 80
    print args.direction
    print "=" * 80
    start(args)
