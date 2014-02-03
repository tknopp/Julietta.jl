
type SourceViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function SourceViewer()
  
  m = GtkSourceLanguageManager()
  l = GtkSourceWidget.language(m,"julia")
  b = GtkSourceBuffer(l)
  v = GtkSourceView(b)
  
  sm = GtkSourceStyleSchemeManager()
  s = style_scheme(sm,"kate")
  style_scheme!(b,s)
    
  GtkSourceWidget.show_line_numbers!(v,true)
  GtkSourceWidget.auto_indent!(v,true)
  
  sw = ScrolledWindow()
  push!(sw,v)
  
  nb = Notebook()
  push!(nb, sw, "tab _one")

  
  btnOpen = ToolButton("gtk-open")

  toolbar = Toolbar()
  push!(toolbar,btnOpen,SeparatorToolItem())
  #G_.style(toolbar,ToolbarStyle.BOTH)  
  
  
  vbox = BoxLayout(:v)
  push!(vbox,toolbar)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  win = GtkWindow(vbox,"Source Viewer")
  resize!(win,600,400)
  showall(win)  
  
  signal_connect(btnOpen, "clicked") do widget
    dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.OPEN,
                        Stock.CANCEL, Response.CANCEL,
                        Stock.OPEN, Response.ACCEPT)
    ret = run(dlg)
    if ret == Response.ACCEPT
      filename = Gtk.bytestring(Gtk._.filename(dlg),true)
      txt = open(readall, filename)
      
      bNew = GtkSourceBuffer(l)
      G_.text(bNew,txt,-1)
      
      vNew = GtkSourceView(bNew)
      style_scheme!(bNew,s)
  
      show_line_numbers!(vNew,true)
      auto_indent!(vNew,true)
  
      swNew = ScrolledWindow()
      push!(swNew,vNew)      
      
      push!(nb, swNew, basename(filename))
      
      showall(nb)   
      
      #setproperty!(win,:title,basename(filename))      
    end
    destroy(dlg)
  end
  
  

  
  sourceViewer = SourceViewer(win.handle)
  Gtk.gc_move_ref(sourceViewer, win)
end
