javascript:(function(){
    var t = document.title,
        e = window.location.href,
        m = "[" + t.replace(/(\\|\/|:|\*|\?|\"|<|>|\|)/gi, '') + "](" + e + ")",
        n = document.createElement("a");

    n.setAttribute("href", e);
    n.innerText = t;
    document.body.appendChild(n);

    var r = document.createRange(),
        o = window.getSelection();

    r.selectNode(n);
    o.removeAllRanges();
    o.addRange(r);

    document.addEventListener("copy", function(ev){
      ev.clipboardData.setData("text/html", n.outerHTML);
      ev.clipboardData.setData("text/plain", m);
      ev.preventDefault();
    }, {once: true});

    document.execCommand("copy");
    document.body.removeChild(n);
  })();