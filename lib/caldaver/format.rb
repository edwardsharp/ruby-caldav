module CalDAVer
    module Format
        class Raw
            def method_missing(m, *args, &block)
                return *args
            end
        end

        class Debug < Raw
        end

        class Pretty < Raw
            def parse_calendar( body )
                result = []
                xml = REXML::Document.new( body )
                REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
                    result += parse_events( c.text )
                }
                result
            end

            def parse_todo( body )
                result = []
                xml = REXML::Document.new( body )
                REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
                    p c.text
                    p parse_tasks( c.text )
                    result += parse_tasks( c.text )
                }
                result
            end

            def parse_tasks( vcal )
                return_tasks = Array.new
                cals = Icalendar.parse(vcal)
                cals.each { |tcal|
                    tcal.todos.each { |ttask|  # FIXME
                        return_tasks << ttask
                    }
                }
                return_tasks
            end

            def parse_events( vcal )
                return_events = []
                fmt = "%H:%M %e.%_m.%Y"
                cals = Icalendar.parse(vcal)
                cals.each { |tcal|
                    tcal.events.each { |ev|
                        # dtstamp, dtstart, dtend, location, transp, description, summary, priority, ip_slass, x-outlookmeeting, x-microsoft_cdo_importance (duration)
                        if ev.dtend.nil?
                          return_events << "%s (%s), %s : %s" % [ ev.dtstart.strftime(fmt), ev.duration, ev.location, ev.summary ]
                        else
                          return_events << "%s -- %s, %s: %s" % [ ev.dtstart.strftime(fmt), ev.dtend.strftime(fmt), ev.location, ev.summary ]
                        end
                        # unless ev.recurrence_id.to_s.empty? # skip recurring events
                    }
                }
                return_events
            end

            def parse_single( body )
                # FIXME: parse event/todo/vcard
                parse_events( body )
            end
        end
    end
end

