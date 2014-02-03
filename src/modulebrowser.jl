
type ModuleBrowser <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function ModuleBrowser()
  @async Base.Help.init_help()

  filename = joinpath(dirname(Base.source_path()),"moduleBrowser.ui")
  if !isfile(filename)
    filename = Pkg.dir("JuliaTools.jl","src","moduleBrowser.ui")
  end
  builder = Builder(filename)

  storeModules = ListStore(String)
  
  tvModules = TreeView(storeModules)
  rModules1 = CellRendererText()
  cModules1 = TreeViewColumn("Module", rModules1, {"text" => 0})
  G_.sort_column_id(cModules1,0)
  push!(tvModules,cModules1)
  
  #G_.sort_column_id(storeModules,0,SortType.ASCENDING)
  
  variables = names(Main)
  
  for v in variables
    if string(typeof(eval(v))) == "Module"
      push!(storeModules, (string(v),) )  
    end
  end
  
  storeContent = ListStore(String,String)
  
  tvContent = TreeView(storeContent)
  rContent1 = CellRendererText()
  cContent1 = TreeViewColumn("Name", rContent1, {"text" => 0})
  cContent2 = TreeViewColumn("Type", rContent1,{"text" => 1})
  G_.sort_column_id(cContent1,0)
  G_.sort_column_id(cContent2,1)
  push!(tvContent,cContent1,cContent2)
  
  #G_.sort_column_id(storeContent,0,SortType.ASCENDING)  
  
  swModules = G_.object(builder,"swModules")
  push!(swModules,tvModules)    
  
  swContent = G_.object(builder,"swContent")
  push!(swContent,tvContent)  
  
  textBuf = TextBuffer()
  textV = TextView(textBuf)  
  swMethods = G_.object(builder,"swMethods")
  push!(swMethods,textV)
  
  textBufHelp = TextBuffer()
  textVHelp = TextView(textBufHelp)  
  swHelp = G_.object(builder,"swHelp")
  push!(swHelp,textVHelp)  
  
  selection = G_.selection(tvModules)
  selectedModule = nothing
  currentIt = nothing  
  
  function updateContent( widget=nothing )
    if hasselection(selection)
      m, currentIt = selected(selection)

      selectedModule = storeModules[currentIt]
      println(selectedModule)
      empty!(storeContent)
      content = names( eval(symbol( selectedModule[1] )) )
      for v in content
        if isdefined(v) 
          push!(storeContent, (string(v), string(typeof(eval(v)))) )  
        end
      end
        
    end
  end
  
  signal_connect(updateContent, selection, "changed")
  
  
  selectionCont = G_.selection(tvContent)
  selectedCont = nothing
  currentItCont = nothing  
  
  function updateMethods( widget=nothing )
    if hasselection(selectionCont)
      m, currentItCont = selected(selectionCont)

      selectedCont = storeContent[currentItCont]
      println(selectedCont)
      if selectedCont[2] == "Function" && isgeneric(eval(symbol(selectedCont[1])))
        txt = string(methods(eval(symbol(selectedCont[1]))))
        
        funcStr = string(selectedModule[1],".",selectedCont[1])
        if haskey(Base.Help.FUNCTION_DICT, funcStr)
          helpVec = Base.Help.FUNCTION_DICT[funcStr]
          txtHelp = ""
          for s in helpVec
            txtHelp = string(txtHelp, s)
          end
        else
          txtHelp = string(funcStr," is not documented")
        end
      elseif selectedCont[2] == "DataType" 
        fields =  names(eval(symbol(selectedCont[1])))
        txt = ""
        for f in fields
          txt = string(txt, string(f),"\n")# "       ",typeof(eval(f)),"\n")
        end             
        txtHelp = ""
      else 
        txt = ""
        txtHelp = ""
      end
      G_.text(textBuf, txt, -1)
      G_.text(textBufHelp, txtHelp, -1)
    end
  end
  
  signal_connect(updateMethods, selectionCont, "changed")   
  
  
  
  win = G_.object(builder,"mainWindow")
  show(win)
  
  moduleBrowser = ModuleBrowser(win.handle)
  Gtk.gc_move_ref(moduleBrowser, win)
end