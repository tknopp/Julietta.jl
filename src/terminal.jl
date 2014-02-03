
function parse_input_line(s::String)
  ccall(:jl_parse_input_line, Any, (Ptr{Uint8},), s)
end

type Terminal <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  entry::Entry
  textView::TextView
end

function redirect()
  global rd
  rd, wr = redirect_stdout()
  global rderr
  rderr, wrerr = redirect_stderr()
  return
end

function readredirected()
  string(readavailable(rd),"\n",readavailable(rderr))
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
  
  #@spawnat 2 rd, wr = redirect_stdout()
  #@spawnat 2 rderr, wrerr = redirect_stderr()
  redirect()

  function doev(timer,::Int32)
    @async begin
      response = readredirected()  
      show(response)
      if !isempty(response)
        insert!(textV,string(response,"\n"))
      end
    end
  end

  timeout = Base.TimeoutAsyncWork(doev)
  start_timer(timeout,1e-1,5e-3)  
  
  terminal = Terminal(vbox, entry, textV)
  
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
  end

  G_.text(term.entry,"")
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
    end
  end
end

