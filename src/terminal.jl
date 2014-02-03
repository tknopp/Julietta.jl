
function parse_input_line(s::String)
  ccall(:jl_parse_input_line, Any, (Ptr{Uint8},), s)
end

type Terminal <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  entry::Entry
  textView::TextView
end

function Terminal()
  
  entry = Entry()
  textBuf = TextBuffer()
  textV = TextView(textBuf)
  
  sw = ScrolledWindow()
  push!(sw,textV)        
  
  vbox = BoxLayout(:v)
  push!(vbox,entry)
  push!(vbox,sw)
  setproperty!(vbox,:expand,sw,true)
    
  rd, wr = redirect_stdout()

  @schedule begin
     while(true)
        response = readavailable(rd)
        if !isempty(response)
          response = replace(response, "From worker 2:	", "")
          insert!(textV,string(response)) #,"\n"
        end
     end
   end
  
  # Redirect stderr on worker  
  @spawnat 2 begin
    rderr, wrerr = redirect_stderr()
    @schedule begin
      while(true)
         response = readavailable(rderr)
         print(response)
      end
    end
  end
  
  terminal = Terminal(vbox.handle, entry, textV)
  
  signal_connect(entry, "key_release_event") do widget, event, other...
  
    if event.keyval == Gtk.GdkKeySyms.Return
      cmd = bytestring(G_.text(terminal.entry))

      execute(terminal,cmd)
    end
    0
  end  
  
  
  Gtk.gc_move_ref(terminal, vbox)
end


function execute(term::Terminal, cmd::String)
  #println("execute cmd...")
  if julietta != nothing
    push!(julietta.hist, cmd)
    start(julietta.spinner)
  end
  G_.sensitive(term.entry, false)

  outputTxt = string("julia> ", cmd, "\n" )
  #insert!(textBuf,G_.end_iter(textBuf),outputTxt)
  insert!(term.textView,outputTxt)

  #if !endswith(cmd,";")
  #  cmd = string(cmd,";show(ans)")
  #end  
      
  ex = parse_input_line(cmd)
  #eval(ex)
  @async begin
    remotecall_fetch(2, eval, ex)
    if julietta != nothing
      #println("execute cmd...2")
      update!(julietta.work)

      stop(julietta.spinner)
      G_.sensitive(julietta.term.entry, true)
      G_.text(julietta.term.entry,"")      
    end
  end
end

