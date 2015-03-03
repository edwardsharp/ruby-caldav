require 'net/https'
require 'uuid'
require 'rexml/document'
require 'rexml/xpath'
require 'date'
require 'icalendar'
require 'time'

['client.rb', 'request.rb', 'net.rb', 'query.rb', 'filter.rb'].each do |f|
    require File.join( File.dirname(__FILE__), 'caldav', f )
end

class Event
    attr_accessor :uid, :created, :dtstart, :dtend, :lastmodified, :summary, :description, :name, :action
end

class Todo
    attr_accessor :uid, :created, :summary, :dtstart, :status, :completed
end
