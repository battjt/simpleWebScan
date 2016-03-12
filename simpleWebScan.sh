#!/bin/bash

# Joe at SolidDesign.net
# 1/26/2016

INTERFACE=10.2.0.1
PORT=8001

TEMP=/tmp/sws.out.$$.ppm
FIFO=/tmp/sws.fifo.$$

mkfifo $FIFO
while true
do 
  (
    IFS=" ?/" read GET RESOLUTION HTTP < $FIFO 
    echo HTTP/1.0 200 OK
    # is resolution a number?
    if [ "$RESOLUTION" -eq "$RESOLUTION" ] 
    then
    echo Scanning at $RESOLUTION DPI... 1>&2
      echo Content-type: image/jpeg
      echo
      scanimage -p --resolution $RESOLUTION > $TEMP
      echo Processing... 1>&2
      convert $TEMP -crop $(convert $TEMP -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:) +repage - |
	  pnmtojpeg
      # rm $TEMP
      echo Done. 1>&2
    else
      # invalid resoltion, so return web page
cat << EOF
Content-type: text/html

<html>
<script>
function myupdate(){
  document.getElementById("text").innerHTML="";
  document.body.style.cursor="pointer";
}
function myclick(r){ 
  document.getElementById("text").innerHTML = "<em>Scanning at "+r+" DPI...</em>"; 
  window.setTimeout(function(){ 
    document.getElementById("scan").innerHTML="<img onload='myupdate()' src='"+r+"?"+new Date().getTime()+"' />"; 
    document.body.style.cursor="wait"; 
  },500)
}
</script>
<body><center>
  <h1>Simple Web Scan</h1>
  Scan Resolution:
EOF
      for r in 100 150 200 300 400 600 1200 2400 4800 9600
      do
        echo "<button onclick='myclick($r)'>$r</button>"
      done
cat << EOF
  <hr/>
  <div id='text'></div>
  <div id='scan'></div>
</center></body></html>
EOF
    fi
  ) |
  nc -l $INTERFACE $PORT > $FIFO

  # drain the fifo
  dd if=$FIFO iflag=nonblock of=/dev/null 2> /dev/null
done
