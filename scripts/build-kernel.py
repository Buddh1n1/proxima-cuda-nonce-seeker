"""Compile project CUDA source with an installed NVRTC. Does not run a GPU."""
import argparse,ctypes,hashlib,os,pathlib,sys
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--nvrtc',required=True,help='Path to installed NVRTC shared library')
p.add_argument('--output',required=True,help='New CUBIN path; an existing file is never overwritten')
a=p.parse_args();library=pathlib.Path(a.nvrtc).resolve();output=pathlib.Path(a.output)
if output.exists():p.error('Output already exists; choose a new file')
directory=os.add_dll_directory(str(library.parent))if sys.platform=='win32'else None
if sys.platform=='win32':os.environ['PATH']=str(library.parent)+os.pathsep+os.environ.get('PATH','')
api=ctypes.CDLL(str(library));handle=ctypes.c_void_p()
api.nvrtcCreateProgram.argtypes=[ctypes.POINTER(ctypes.c_void_p),ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int,ctypes.c_void_p,ctypes.c_void_p]
api.nvrtcCompileProgram.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_char_p)]
for size in ['nvrtcGetProgramLogSize','nvrtcGetCUBINSize']:getattr(api,size).argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_size_t)]
for read in ['nvrtcGetProgramLog','nvrtcGetCUBIN']:getattr(api,read).argtypes=[ctypes.c_void_p,ctypes.c_void_p]
api.nvrtcDestroyProgram.argtypes=[ctypes.POINTER(ctypes.c_void_p)]
def check(code):
 if code!=0:raise RuntimeError('NVRTC error '+str(code))
source=pathlib.Path(__file__).resolve().parents[1]/'seeker/src/kernel.cu'
check(api.nvrtcCreateProgram(ctypes.byref(handle),source.read_bytes(),b'kernel.cu',0,None,None))
try:
 opts=[b'--gpu-architecture=sm_86',b'--std=c++14',b'--ptxas-options=-v',b'--device-as-default-execution-space']
 status=api.nvrtcCompileProgram(handle,len(opts),(ctypes.c_char_p*len(opts))(*opts))
 size=ctypes.c_size_t();check(api.nvrtcGetProgramLogSize(handle,ctypes.byref(size)))
 log=ctypes.create_string_buffer(size.value);check(api.nvrtcGetProgramLog(handle,log))
 if status:print(log.value.decode(errors='replace'),file=sys.stderr)
 check(status);check(api.nvrtcGetCUBINSize(handle,ctypes.byref(size)))
 blob=ctypes.create_string_buffer(size.value);check(api.nvrtcGetCUBIN(handle,blob))
 with output.open('xb')as f:f.write(blob.raw)
 print('SM86 CUBIN SHA256 '+hashlib.sha256(blob.raw).hexdigest()+'; no GPU execution')
finally:
 check(api.nvrtcDestroyProgram(ctypes.byref(handle)))
 if directory:directory.close()
