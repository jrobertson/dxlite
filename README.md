# Introducing the dxlite gem

    require 'dxlite' 

    dx = DxLite.new 'http://a0.jamesrobertson.eu/health/dynarex.json'
    recs = dx.records

    title = "Jogging slowly  #jogging #easy"
    r = dx.find_all_by_title title
    r2 = dx.find_by_title title
    dx.create(url: 'about:blank', title: 'ABC hello!')
    dx.save '/tmp/health.json'

The above example loads a Dynarex document in JSON format. DxLite can do the following:

* read an existing Dynarex document in JSON format
* find multiple records by field value
* find a single record by field value
* create a new record
* save the document in JSON format
* return all records using methods :record or :all

## Resources

* dxlite https://rubygems.org/gems/dxlite

dxlite gem dynarex lite
