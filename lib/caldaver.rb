require 'optparse'

['format.rb'].each do |f|
  require File.join( File.dirname(__FILE__), 'caldaver', f )
end

# caldav --user USER --password PASSWORD --uri URI --command COMMAND
# caldav --user martin@solnet.cz --password test --uri https://mail.solnet.cz/caldav.php/martin.povolny@solnet.cz/test --command create_event 

# caldav report --begin 2012-01-01 --end 2012-07-01 --format raw --user USER --password PASSWORD --uri https://in.solnet.cz/caldav.php/martin.povolny@solnet.cz/public
# caldav get --user USER --password PASSWD --uri https://mail.solnet.cz/caldav.php/martin.povolny%40solnet.cz/public/ --uuid 64d0b933-e916-4755-9e56-2f4d0d9068cb

module CalDAVer
  class CalDAVer
    def create_object( options )
      if options[:raw]
        # STDIN
        return STDIN.read(nil)
      else
        # options[:subject]
        # options[:login]
        # options[:summary]
        # options[:begin]
        # options[:end]
        # options[:due]
 
        case options[:what].intern
        when :task # FIXME
        when :event # FIXME
        when :contact # FIXME
        else
          print_help_and_exit if options[:command].to_s.empty? or options[:uri].to_s.empty?
        end
      end
    end
  
    def print_help_and_exit
      puts @o.help
      exit 1
    end
  
    def run_args( args )
      options = {}
      @o = OptionParser.new do |o|
        o.banner = "Usage: caldaver [command] [options]"
        o.on('-p', '--password [STRING]', String, 'Password')     { |p|   options[:password] = p }
        o.on('-u', '--user [STRING}',     String, 'User (login)') { |l|   options[:login]    = l }
        o.on('--uri [STRING]',        String, 'Calendar URI') { |uri| options[:uri] = uri }
        o.on('--format [STRING]',     String, 'Format of output: raw,pretty,[debug]') { 
                                                                |fmt| options[:format] = fmt }
        ##o.on('--command [STRING]',    String, 'Command')      { |c|   options[:command] = c }
        o.on('--uuid [STRING]',       String, 'UUID')         { |u|   options[:uuid] = u }
        # what to create
        o.on('--what [STRING]',       String, 'Event/task/contact') { |c| options[:command]  = command }
        o.on('--raw',                         'Read raw data (event/task/contact) from STDIN') { |raw|   options[:raw] = true }
        # report and event options
        o.on('--begin [DATETIME]',    String, 'Start time')   { |dt|  options[:begin] = dt }
        o.on('--end [DATETIME]',      String, 'End time')     { |dt|  options[:end]   = dt }
        o.on('--due [DATETIME]',      String, 'Due time')     { |dt|  options[:due]   = dt }
        #o.on('--begin [DATETIME]',    DateTime, 'Start time') { |dt|  options[:begin]    = dt }
        #o.on('--end [DATETIME]',      DateTime, 'End time')   { |dt|  options[:end]      = dt }
        # event options
        o.on('--summary  [string]',   String, 'summary of event/task')  { |s|  options[:summary]  = s }
        o.on('--location [string]',   String, 'location of event/task') { |s|  options[:location] = s }
        o.on('--subject  [string]',   String, 'subject of event/task')  { |s|  options[:subject]  = s }
        o.on('-h') { print_help_and_exit }
      end
  
      options[:command] =  @o.parse( args )[0]
  
      print_help_and_exit if options[:command].to_s.empty? or options[:uri].to_s.empty?
      cal = CalDAV::Client.new(options[:uri], options[:login], options[:password])
  
      formater = case options[:format].to_s.intern
                   when :raw
                     Format::Raw.new
                   when :pretty
                     Format::Pretty.new
                   else
                     Format::Debug.new
                   end
  
      case options[:command].intern
      when :create
        obj = create_object(options)
        p cal.raw_put(obj)
  
      when :delete
        p cal.delete(options[:uuid])
  
      when :modify
        obj = create_object(options)
        p cal.raw_put(obj)
  
      when :get
        res = cal.get( options[:uuid] )
        puts formater.parse_single(res.body)
  
      when :report
        res = cal.report(options[:begin], options[:end])
        require 'pry'
        puts formater.parse_calendar(res.body)
  
      when :todo #fixme
        res = cal.todo
        puts formater.parse_todo( res.body )
  
      else
        print_help_and_exit
      end
    end
  end
end
