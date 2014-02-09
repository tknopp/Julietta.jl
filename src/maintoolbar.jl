
type MainToolbar <: Gtk.GtkToolbarI
  handle::Ptr{Gtk.GObjectI}
  btnNew
  btnOpen
  btnSave
  btnSaveAs 
  btnUndo
  btnRedo
  btnRun
  btnIndent
  btnUnindent
  btnComment
  spinner
end

function MainToolbar()
  btnNew = ToolButton("gtk-new")
  btnOpen = ToolButton("gtk-open")
  btnSave = ToolButton("gtk-save")
  btnSaveAs = ToolButton("gtk-save-as")  
  btnUndo = ToolButton("gtk-undo")
  btnRedo = ToolButton("gtk-redo")
  btnRun = ToolButton("gtk-media-play")
  btnIndent = ToolButton("gtk-indent")
  btnUnindent = ToolButton("gtk-unindent")
  btnComment = ToolButton("gtk-indent")
  btnUncomment = ToolButton("gtk-unindent")  
  btnAbout = ToolButton("gtk-about")
  
  toolbar = Toolbar()
  push!(toolbar,btnNew,btnOpen,btnSave,btnSaveAs,SeparatorToolItem())
  push!(toolbar,btnUndo,btnRedo,SeparatorToolItem())
  push!(toolbar,btnRun,SeparatorToolItem())
  push!(toolbar,btnIndent,btnUnindent,SeparatorToolItem()) 
  push!(toolbar,btnComment,btnUncomment,SeparatorToolItem()) 
  G_.style(toolbar,ToolbarStyle.ICONS) #BOTH
  #G_.icon_size(toolbar,IconSize.MENU)

  
  btnHelp = ToolButton("gtk-help")
  btnSettings = ToolButton("gtk-preferences")
  btnClear = ToolButton("gtk-clear")
  push!(toolbar,btnHelp,btnSettings,btnClear, btnAbout)
  
  # Add spinner
  spItem = ToolItem()
  spinner = Spinner()
  G_.size_request(spinner, 23,-1)
  push!(spItem,spinner)
  spSep = SeparatorToolItem()
  setproperty!(spSep,:draw,false)
  setproperty!(spItem,:margin, 5)
  push!(toolbar,spSep,spItem)
  G_.expand(spSep,true) 
  
  maintoolbar = MainToolbar(toolbar.handle, 
  btnNew,
  btnOpen,
  btnSave,
  btnSaveAs,
  btnUndo,
  btnRedo,
  btnRun,
  btnIndent,
  btnUnindent,
  btnComment,
  spinner
  ) 
  
  signal_connect(btnNew, "clicked") do widget
    push!(julietta.editor, SourceDocument(julietta.editor.lang,julietta.editor.style))
  end  
  
  signal_connect(btnOpen, "clicked") do widget
    doc = SourceDocument(julietta.editor.lang,julietta.editor.style)
    if open(doc)
      push!(julietta.editor, doc)
    end
  end
  
  signal_connect(btnSave, "clicked") do widget
    save(julietta.editor.currentDoc)
  end  
  
  signal_connect(btnSaveAs, "clicked") do widget
    saveas(julietta.editor.currentDoc)
  end    

  signal_connect(btnUndo, "clicked") do widget
    buf = julietta.editor.currentDoc.buffer
    undo!(buf) #TODO use active buffer
    G_.sensitive(btnUndo, canundo(buf))
    G_.sensitive(btnRedo, canredo(buf))
  end
  
  signal_connect(btnRedo, "clicked") do widget
    buf = julietta.editor.currentDoc.buffer  
    redo!(buf) #TODO use active buffer
    G_.sensitive(btnUndo, canundo(buf))
    G_.sensitive(btnRedo, canredo(buf))    
  end
  
  signal_connect(btnIndent, "clicked") do widget
    indent!(julietta.editor.currentDoc)
  end
  
  signal_connect(btnUnindent, "clicked") do widget
    unindent!(julietta.editor.currentDoc)
  end
  
  signal_connect(btnComment, "clicked") do widget
    comment!(julietta.editor.currentDoc)
  end  
  
  signal_connect(btnUncomment, "clicked") do widget
    uncomment!(julietta.editor.currentDoc)
  end

  #signal_connect(currentDoc.buffer, "changed") do widget, args...
  #  G_.sensitive(btnUndo, canundo(currentDoc.buffer))
  #  G_.sensitive(btnRedo, canredo(currentDoc.buffer))
  #end    
  
  signal_connect(btnRun, "clicked") do widget
    script = text(julietta.editor.currentDoc)
    if julietta != nothing
      execute(julietta.term, script)
    end
  end 
  
  
  signal_connect(btnHelp, "clicked") do widget
    ModuleBrowser()
  end

  signal_connect(btnSettings, "clicked") do widget
    dlg = SettingsDialog()
    ret = run(dlg)
    destroy(dlg)
  end  
  
  signal_connect(btnClear, "clicked") do widget
    start(julietta.maintoolbar.spinner)
    @async begin
      rmprocs(2)
      addprocs(1)
      update!(julietta.work)
      stop(julietta.maintoolbar.spinner)
    end
  end  
  
  
  signal_connect(btnAbout, "clicked") do widget
    dlg = AboutDialog()
    G_.program_name(dlg,"Julietta")
    G_.version(dlg,"0.0.0")
    
    ret = run(dlg)
    destroy(dlg)
  end     
  
  Gtk.gc_move_ref(maintoolbar, toolbar)
end