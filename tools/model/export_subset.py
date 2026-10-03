import sys,os,shutil,json,torch
from ultralytics.nn.modules import block
def dfl_forward(self,x):
    b,_,a=x.shape
    p=x.view(b,4,self.c1,a).softmax(2)
    w=torch.arange(self.c1,dtype=x.dtype).view(1,1,self.c1,1)
    return (p*w).sum(2)
block.DFL.forward=dfl_forward
from ultralytics import YOLO
w,sz,out,keepf=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4]
keep=json.load(open(keepf))
y=YOLO(w)
head=y.model.model[-1]
idx=torch.tensor(keep)
for seq in head.cv3:
    c=seq[2]
    nw=torch.nn.Conv2d(c.in_channels,len(keep),1)
    nw.weight.data=c.weight.data[idx].clone()
    nw.bias.data=c.bias.data[idx].clone()
    seq[2]=nw
head.nc=len(keep)
head.no=head.nc+head.reg_max*4
p=y.export(format="onnx",imgsz=sz,opset=12,simplify=True,dynamic=False,batch=1)
shutil.move(p,out);print(out,os.path.getsize(out))
