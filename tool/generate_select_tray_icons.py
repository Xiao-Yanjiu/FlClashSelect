import argparse,struct,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser(description='Render selective proxy SVG tray states with resvg')
p.add_argument('--resvg',required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
sizes=[16,20,24,32,40,48,64]
for name in ['status_system','status_tun']:
 with tempfile.TemporaryDirectory(prefix='select-tray-icons-') as folder:
  images=[]
  for size in sizes:
   target=Path(folder)/f'{size}.png'
   subprocess.run([a.resvg,'--width',str(size),'--height',str(size),str(root/f'assets_source/images/icon/{name}.svg'),str(target)],check=True,capture_output=True)
   images.append(target.read_bytes())
  offset=6+16*len(sizes)
  directory=[]
  for size,data in zip(sizes,images):
   directory.append(struct.pack('<BBBBHHII',size,size,0,0,1,32,len(data),offset));offset+=len(data)
  output=root/f'assets/images/tray/windows/{name}.ico'
  output.write_bytes(struct.pack('<HHH',0,1,len(sizes))+b''.join(directory)+b''.join(images))
  print(output.name)
