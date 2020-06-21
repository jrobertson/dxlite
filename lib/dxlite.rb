#!/usr/bin/env ruby

# file: dxlite.rb

require 'c32'
require 'json'
require 'recordx'
require 'rxfhelper'

class DxLite
  using ColouredText

  attr_accessor :summary
  attr_reader :records

  def initialize(s, debug: false)

    @debug = debug

    buffer, type = RXFHelper.read(s)
    puts 'type: ' + type.inspect if @debug
    
    case type
      
    when :file
      
      h = JSON.parse(buffer, symbolize_names: true)
      @filepath = s
      
      @summary = h[:summary]
      @records = h[:records]
    
    when :text
      
      @summary = {schema: s}
      @records = []
      
    end
    
    @schema = @summary[:schema]

    @summary.merge! @summary[:schema][/(?<=\[)[^\]]+/].split(',')\
        .map {|x|[x.strip, nil] }.to_h
    
    # for each summary item create get and set methods
    
    @summary.each do |key, value|
      
      define_singleton_method(key) { @summary[key] }
      
      define_singleton_method (key.to_s + '=').to_sym do |value|
        @summary[key] = value
      end      
      
    end
    
    @fields = @summary[:schema][/(?<=\()[^\)]+/].split(',').map(&:strip)

    @fields.each do |x|

      define_singleton_method ('find_all_by_' + x).to_sym do |value|
        @records.select {|rec| rec[x.to_sym] == value }
      end

      define_singleton_method ('find_by_' + x).to_sym do |value|
        @records.find {|rec| rec[x.to_sym] == value }
      end

    end

  end  

  def all()

    @records.map do |h|
      RecordX.new(h, self, h.object_id, h[:created], h[:last_modified])
    end

  end  
  
  def create(h)
    @records << h
  end
  
  # Parses 1 or more lines of text to create or update existing records.

  def parse(obj=nil)
    
    if obj.is_a? Array then
      
      unless schema() then
        cols = obj.first.keys.map {|c| c == 'id' ? 'uid' : c} 
        self.schema = "items/item(%s)" % cols.join(', ')
      end
        
      obj.each {|x| self.create x }
      return self 
      
    end  
  end
  
  alias import parse

  def save(file=@filepath)
    File.write file, @records.to_json
  end
  
  # Updates a record from an id and a hash containing field name and field value.
  #  dynarex.update 4, name: Jeff, age: 38  
  
  def update(id, obj)
    
    if @debug then
      puts 'inside update'.info
      puts ('id: ' + id.inspect).debug
      puts ('obj.class: '  + obj.class.inspect).debug
    end
    
    r = @records.find {|x| x.object_id == id}
    r.merge!(obj)
  end
  
end
