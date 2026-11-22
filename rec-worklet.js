class SixRec extends AudioWorkletProcessor {
  constructor(){ super(); this.on=false; this.buf=new Float32Array(4096); this.n=0; this.t=0;
    this.port.onmessage = e => { this.on = e.data; if(!this.on){ this.flush(); this.port.postMessage({done:true}); } }; }
  flush(){ if(this.n){ this.port.postMessage({t:this.t, d:this.buf.slice(0,this.n)}); this.n=0; } }
  process(inputs){
    const inp = inputs[0];
    if (this.on && inp && inp[0]) {
      const ch = inp[0];
      if (this.n + ch.length > this.buf.length) this.flush();
      if (this.n === 0) this.t = currentTime;
      if (inp.length > 1) { const r = inp[1]; for (let i=0;i<ch.length;i++) this.buf[this.n+i] = (ch[i]+r[i])*0.5; }
      else this.buf.set(ch, this.n);
      this.n += ch.length;
      if (this.n >= this.buf.length) this.flush();
    }
    return true;
  }
}
registerProcessor('jampass-rec', SixRec);
