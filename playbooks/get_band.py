import sys
import numpy as np
from scipy.interpolate import interp1d

fname = sys.argv[1]


data = np.loadtxt(fname, delimiter=" ",ndmin=2)


f = np.empty((len(data[:,0]),101))

minval = np.amin(data[:,1])
maxval = np.amax(data[:,2])

for i in range (0,len(data[:,0])):
	y = [data[i,0],data[i,0]]
	a = np.empty((0))
	a = np.append(a, y)
	a = np.append(a, y)
	old_indices = data[i,1:3]
	new_indices = np.linspace(minval, maxval, num=101, endpoint=True)
	lin = interp1d(old_indices, y,fill_value=0.0,bounds_error=False)
	f[i] = lin(new_indices)

total = np.trim_zeros(f.sum(axis=0))

print fname
print "Max bandwidth: ",np.amax(total)," Mb/s ", "(",np.amax(total)/8.0, " MB/s)"
print "Average bandwidth: ",np.average(total)," Mb/s ", "(",np.average(total)/8.0, " MB/s)"
