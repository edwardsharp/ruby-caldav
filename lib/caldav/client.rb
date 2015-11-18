module CalDAV
    class Client
        include Icalendar
        attr_accessor :host, :port, :url, :user, :password, :ssl

        def initialize( *args )
            case args.length
            when 3
                __init_from_uri( *args )
            when 5
                __init_from_host_port( *args )
            else
                raise "#{self.class.to_s}: invalid number of arguments: #{args.length}"
            end
        end

        def __init_from_uri( suri, user, password )
            uri = URI( suri )
            @host     = uri.host
            @port     = uri.port
            @url      = [ uri.scheme, '://', uri.host, uri.path ].join('') # FIXME: port?
            @user     = user
            @password = password 
            @ssl      = uri.scheme == 'https'
        end

        def __init_from_host_port( host, port, url, user, password )
           @host     = host
           @port     = port
           @url      = url
           @user     = user
           @password = password 
           @ssl      = port == 443
        end
    
        def __create_http
            http = Net::HTTP.new(@host, @port)
            http.use_ssl = @ssl
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            #http.set_debug_output $stderr
            http
        end
    
        def report( start, stop )
            res = nil
            __create_http.start {|http|
                req = Net::HTTP::Report.new(@url, {'Content-Type'=>'application/xml'} )
                req.basic_auth @user, @password
                req.body = CalDAV::Request::ReportVEVENT.new( start, stop ).to_xml
                res = http.request( req )
            }
            res
        end
        
        def get( uuid )
            res = nil
            __create_http.start {|http|
                req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
                req.basic_auth @user, @password
                res = http.request( req )
            }
            # FIXME: process HTTP code
            res
        end
    
        def delete( uuid )
            __create_http.start {|http|
                req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
                req.basic_auth @user, @password
                res = http.request( req )
            }
        end

        # FIXME
        def __uuid_from_raw( data )
          data.split("\n").each { |row| return $1 if row =~ /^UID:(.*)$/ }
        end

        def raw_put( data )
            res = nil
            uuid = __uuid_from_raw(data)
            uuid ||= UUID.generate

            http = Net::HTTP.new(@host, @port) 
            __create_http.start { |http|
                req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics", {'Content-Type'=>'text/calendar'})
                req.basic_auth @user, @password
                req.body = data
                res = http.request(req)
            }
            [uuid, res ]
          end
      
          def create event
            # nowstr = DateTime.now.strftime "%Y%m%dT%H%M%SZ"

            # Create a calendar with an event
            cal = Icalendar::Calendar.new
            cal.event do |e|
              e.dtstart     = Icalendar::Values::Date.new(event.dtstart)
              e.dtend       = Icalendar::Values::Date.new(event.dtend)
              e.summary     = event.summary
              e.description = event.description
              e.ip_class    = "PRIVATE"
              e.url         = event.url
            end

            dings  = cal.to_ical
            uuid   = cal.event.uid

            res = nil
            http = Net::HTTP.new(@host, @port) 
            __create_http.start { |http|
                req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
              req['Content-Type'] = 'text/calendar'
              req.basic_auth @user, @password
              req.body = dings
              res = http.request(req)
            }
            [uuid, res]
        end
    
        def add_alarm tevent, altCal="Calendar"
        #[#<Icalendar::Alarm:0x10b9d1b90 @name=\"VALARM\", @components={}, @properties={\"trigger\"=>\"-PT5M\", \"action\"=>\"DISPLAY\", \"description\"=>\"\"}>]    
            dtstart_string = ( Time.parse(tevent.dtstart.to_s) + Time.now.utc_offset.to_i.abs ).strftime "%Y%m%dT%H%M%S"
            dtend_string = ( Time.parse(tevent.dtend.to_s) + Time.now.utc_offset.to_i.abs ).strftime "%Y%m%dT%H%M%S"
            alarmText = <<EOL
BEGIN:VCALENDAR
VERSION:2.0
PRODID:Ruby iCalendar
BEGIN:VEVENT
UID:#{tevent.uid}
SUMMARY:#{tevent.summary}
DESCRIPTION:#{tevent.description}
DTSTART:#{dtstart_string}
DTEND:#{dtend_string}
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;RELATED=START:-PT5M
DESCRIPTION:Reminder
END:VALARM
BEGIN:VALARM
TRIGGER:-PT5M
ACTION:EMAIL
ATTENDEE:#{tevent.organizer}
SUMMARY:#{tevent.summary}
DESCRIPTION:#{tevent.description}
TRIGGER:-PT5M
END:VALARM
END:VEVENT
END:VCALENDAR
EOL
            p alarmText
            res = nil
            puts "#{@url}/#{tevent.uid}.ics"
            thttp = __create_http.start
            #thttp.set_debug_output $stderr
            req = Net::HTTP::Put.new("#{@url}/#{tevent.uid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
            req.basic_auth @user, @password
            req.body = alarmText
            res = thttp.request( req )
            p res.inspect
    
            tevent.uid
        end
        
        def update event
            dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0

BEGIN:VTIMEZONE
TZID:/Europe/Vienna
X-LIC-LOCATION:Europe/Vienna
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
END:STANDARD
END:VTIMEZONE

BEGIN:VEVENT
CREATED:#{event.created}
UID:#{event.uid}
SUMMARY:#{event.summary}
DTSTART;TZID=Europe/Vienna:#{event.dtstart}
DTEND;TZID=Europe/Vienna:#{event.dtend.rfc3339}
END:VEVENT
END:VCALENDAR"""
    
            res = nil
            __create_http.start {|http|
                req = Net::HTTP::Put.new("#{@url}/#{event.uid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
                req.basic_auth @user, @password
                req.body = dings
                res = http.request( req )
            }
            event.uid
        end
    
        def todo 
            res = nil
            __create_http.start {|http|
                req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml'} )
                req.basic_auth @user, @password
                req.body = CalDAV::Request::ReportVTODO.new.to_xml
                res = http.request( req )
            }
            # FIXME: process HTTP code
            res
        end
        
        def filterTimezone( vcal )
            data = ""
            inTZ = false
            vcal.split("\n").each{ |l| 
                inTZ = true if l.index("BEGIN:VTIMEZONE") 
                data << l+"\n" unless inTZ 
                inTZ = false if l.index("END:VTIMEZONE") 
            }
            data
        end
    end
end
