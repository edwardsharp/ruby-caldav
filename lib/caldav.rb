'''
caldav.rb - originally from https://github.com/loosecannon93/ruby-caldav/blob/master/lib/caldav.rb
highly modified (specifically to use the icalendar class to parse existing events) by Bradley McCrorey <bradley.mccrorey@contegix.com>
'''

require 'net/https'
require 'rubygems'
require 'uuid'
require 'rexml/document'
require 'rexml/xpath'
require 'date'
require 'icalendar'
require 'time'

class Event
    attr_accessor :uid, :created, :dtstart, :dtend, :lastmodified, :summary, :description, :name, :action
end

class Todo
    attr_accessor :uid, :created, :summary, :dtstart, :status, :completed
end

module Net
    class HTTP
        class Report < HTTPRequest
            METHOD = 'REPORT'
            REQUEST_HAS_BODY = true
            RESPONSE_HAS_BODY = true
        end
    end
end

class Caldav
    include Icalendar
    attr_accessor :host, :port, :url, :user, :password

    def initialize( host, port, url, user, password )
       @host = host
       @port = port
       @url = url
       @user = user
       @password = password 
    end

    def report start, stop
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VEVENT'>
        <c:time-range start='#{start}Z' end='#{stop}Z'/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        http = Net::HTTP.new(@host, @port)
        #http.set_debug_output $stderr

        http.start {|http|

            req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml'} )
            req.basic_auth @user, @password
            req.body = dings


            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
            result <<  c.text
        }
        return parseVcal(result)
    end
    
    def get uuid
        res = nil
        Net::HTTP.start( @host, @port ) {|http|
            req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
            req.basic_auth @user, @password
            res = http.request( req )
        }
        return parseVcal( res.body )
    end

    def delete uuid
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
            req.basic_auth @user, @password
            res = http.request( req )
        }
    end

    def create event
        now = DateTime.now 
        nowstr = now.strftime "%Y%m%dT%H%M%SZ"
        uuid_generator =  UUID.new
        uuid = uuid_generator.generate

     dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0
BEGIN:VEVENT
CREATED:#{nowstr}
UID:#{uuid}
SUMMARY:#{event.summary}
DTSTART:#{event.dtstart.strftime("%Y%m%dT%H%M%S")}
DTEND:#{event.dtend.strftime("%Y%m%dT%H%M%S")}
END:VEVENT
END:VCALENDAR"""



        res = nil
        http = Net::HTTP.new(@host, @port) 
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        req.basic_auth @user, @password
        req.body = dings
        res = http.request( req )
        puts @user, @password, @url, @host, @port, dings
        return uuid, res
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
        thttp = Net::HTTP.start(@host, @port)
        #thttp.set_debug_output $stderr
        req = Net::HTTP::Put.new("#{@url}/#{tevent.uid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
        req.basic_auth @user, @password
        req.body = alarmText
        res = thttp.request( req )
        p res.inspect

        return tevent.uid
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
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Put.new("#{@url}/#{event.uid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
            req.basic_auth @user, @passowrd
            req.body = dings
            res = http.request( req )
        }
        return event.uid
    end

    def todo 
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VTODO'>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml'} )
            req.basic_auth @user, @password
            req.body = dings
            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
            result << parseVcal( c.text )
        }
        return result
    end
    
    def parseVcal( vcal )
        return_events = Array.new
        cals = Icalendar.parse(vcal)
        cals.each { |tcal|
            tcal.events.each { |tevent|
                if tevent.recurrence_id.to_s.empty? # skip recurring events
                    return_events << tevent
                end
            }
        }
        return return_events
    end
    
    def filterTimezone( vcal )
        data = ""
        inTZ = false
        vcal.split("\n").each{ |l| 
            inTZ = true if l.index("BEGIN:VTIMEZONE") 
            data << l+"\n" unless inTZ 
            inTZ = false if l.index("END:VTIMEZONE") 
        }
        return data
    end

    def getField( name, l )
        fname = (name[-1] == ':'[0]) ? name[0..-2] : name 
        return NIL unless l.index(fname)
        idx = l.index( ":", l.index(fname))
        return l[ idx+1..-1 ] 
    end
end