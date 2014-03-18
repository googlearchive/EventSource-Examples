class BasicDisplay

  class DisplayThread

    def initialize(inbound_queue)
      @inbound_queue = inbound_queue
    end

    def run
      @thread = Thread.new do
        while true
          msg = @inbound_queue.pop
          if msg
            puts "#{msg['client']}: #{msg['text']}"
          else
            break
          end
        end
      end
    end

    def join
      @thread.join
    end
  end

  def initialize(outbound_queue, client_name, inbound_queue)
    @outbound_queue = outbound_queue
    @client_name = client_name
    @inbound_queue = inbound_queue
    @display_thread = setup_display(inbound_queue)
    @display_thread.run
  end

  def setup_display(inbound_queue)
    DisplayThread.new(inbound_queue)
  end

  def run
    input_lines.each { |line| queue_text(line) }

    cleanup_display
    close
  end

  def input_lines
    Enumerator.new do |y|
      while line = STDIN.gets
        line.strip!
        if line.empty?
          break
        else
          y << line
        end
      end
    end
  end

  def cleanup_display
    # No-op
  end

  def queue_text(msg)
    packet = {:client => @client_name, :text => msg}
    @outbound_queue << packet
  end

  def close
    @outbound_queue << false
    @inbound_queue << false
    @display_thread.join
  end
end

class CursesDisplay < BasicDisplay
  require 'curses'

  class CursesDisplayThread

    def initialize(inbound_queue, chat_win, limit)
      @inbound_queue = inbound_queue
      @chat_win = chat_win
      @limit = limit
    end

    def run
      @thread = Thread.new do
        messages = []
        while true
          msg = @inbound_queue.pop
          if msg
            messages << msg
            min = [messages.length, @limit].min
            messages = messages[-min, min]
            @chat_win.clear
            messages.each_with_index do |value, index|
              @chat_win.setpos(index, 0)
              @chat_win.addstr("#{value["client"]}: #{value["text"]}")
            end
            @chat_win.refresh
          else
            break
          end
        end
      end
    end

    def join
      @thread.join
    end
  end

  def setup_display(inbound_queue)
    limit = setup_screen
    CursesDisplayThread.new(inbound_queue, @chat_win, limit)
  end

  def setup_screen
    @scr = Curses.init_screen
    @scr.keypad(true)
    Curses.cbreak
    Curses.curs_set(0)
    rows = @scr.maxy
    cols = @scr.maxx

    #create our windows
    @div_win = Curses::Window.new(1, cols + 1, rows - 3, 0)
    @chat_win = Curses::Window.new(rows - 3, cols, 0, 0)
    @msg_win = Curses::Window.new(1, cols, rows - 2, 0)
    @instructions_win = Curses::Window.new(1, cols, rows - 1, 0)

    # setup the divider
    div = "=" * cols
    @div_win.addstr(div)
    @div_win.refresh

    @instructions_win.addstr("Type a message, Hit <ENTER> to send. An empty message quits the program")
    @instructions_win.refresh

    rows - 4
  end

  def input_lines
    Enumerator.new do |y|
      current_msg = ''
      while true
        c = @msg_win.getch
        if c == 10
          if current_msg.empty?
            break
          else
            @msg_win.clear
            @msg_win.refresh
            line = current_msg
            current_msg = ''
            y << line
          end
        else
          current_msg += c.chr
        end
      end
    end
  end

  def cleanup_display
    @scr.keypad(false)
    Curses.nocbreak
    Curses.curs_set(1)
    Curses.close_screen
  end

end