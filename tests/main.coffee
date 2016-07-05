# gulp test_coffee && mocha app/Conform/tests/main.js
expect = require('chai').expect
global.root_path = '/www/self/mapodofu'

require('coffee-script/register')
require(root_path + '/loader_base')
#require(__dirname + '/../main.coffee')


global.test_fn =
	pass: (v)->
		v
	delay_pass: (v)->
		Promise.delay(200).then ()-> v
	mutate: (v)->
		v + 'bob'
	delay_mutate: (v)->
		Promise.delay(200).then ()-> v + 'bob'
	reject: (v)->
		throw new Error('fail')
	delay_reject: (v)->
		Promise.delay(200).then ()->
			 throw new Error('fail')



###
conform = new Conform({test1:'moe', test2:'sue'})
rules =
	test1:'~test_fn.delay_reject &test_fn.delay_mutate'
	test2:'test_fn.delay_mutate'
conform.fields_rules(rules).then (o)->
	c o
	c conform.errors
###


####
describe "Test Suite", ()->

	# Avoid the mocha default suite timeout by setting it higher
	@timeout(10000)


	it "rules string separation", ()->
		expect( Conform::compile_rules('bob bob, bob ,bob , bob').length ).to.equal(5)
	describe ".compile_rule", ()->
		it '!a.string', ()->
			expect( Conform::compile_rule('!a.string') ).to.deep.equal( { flags: { break: true }, params: [], fn_path: 'a.string' } )
		it '!!a.string', ()->
			expect( Conform::compile_rule('!!a.string') ).to.deep.equal( { flags: { break_all: true }, params: [], fn_path: 'a.string' } )
		it '?!a.above|10', ()->
			expect( Conform::compile_rule('?!a.above|10') ).to.deep.equal( { flags: { optional: true, break: true }, params: [ '10' ], fn_path: 'a.above' } )
		it '~?&&a.function', ()->
			expect( Conform::compile_rule('~?&&a.function') ).to.deep.equal( { flags: { full_continuity: true, not: true, optional: true }, params: [], fn_path: 'a.function' } )
	describe "validation", ()->
		it 'mutate', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			conform.fields_rules({test1:'test_fn.pass test_fn.mutate', test2:'test_fn.pass test_fn.mutate'}).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebob', test2: 'suebob' } )
				done()
		it 'mutates', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			conform.fields_rules({test1:'test_fn.pass test_fn.mutate test_fn.mutate', test2:'test_fn.pass test_fn.mutate test_fn.mutate'}).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebobbob', test2: 'suebobbob' } )
				done()
		it 'delayed_mutates', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			conform.fields_rules({test1:'test_fn.pass test_fn.delay_mutate test_fn.delay_mutate', test2:'test_fn.pass test_fn.delay_mutate test_fn.delay_mutate'}).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebobbob', test2: 'suebobbob' } )
				done()
		it 'reject', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'test_fn.pass test_fn.reject test_fn.delay_mutate'
				test2:'test_fn.pass test_fn.reject test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( conform.errors.length ).to.equal( 2 )
				expect( conform.field_errors.test1.length ).to.equal( 1 )
				expect( conform.field_errors.test2.length ).to.equal( 1 )
				done()
		it 'delayed reject', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'test_fn.pass test_fn.delay_reject test_fn.delay_mutate'
				test2:'test_fn.pass test_fn.delay_reject test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( conform.errors.length ).to.equal( 2 )
				expect( conform.field_errors.test1.length ).to.equal( 1 )
				expect( conform.field_errors.test2.length ).to.equal( 1 )
				done()
		it 'optional reject', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'test_fn.pass ?test_fn.reject test_fn.delay_mutate'
				test2:'test_fn.pass ?test_fn.reject test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebob', test2: 'suebob' } )
				expect( conform.errors.length ).to.equal( 0 )
				done()
		it 'optional delayed reject', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'test_fn.pass ?test_fn.delay_reject test_fn.delay_mutate'
				test2:'test_fn.pass ?test_fn.delay_reject test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebob', test2: 'suebob' } )
				expect( conform.errors.length ).to.equal( 0 )
				done()

		it 'full continuity without error', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'?!test_fn.reject'
				test2:'&&test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { test2: 'suebob' } )
				done()
		it 'full continuity with error', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'!test_fn.reject'
				test2:'&&test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { } )
				done()
		it 'full continuity with delayed error', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'!test_fn.delay_reject'
				test2:'&&test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { } )
				done()
		it 'continuity with delayed error', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'test_fn.delay_reject &test_fn.delay_mutate'
				test2:'test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { test2: 'suebob' } )
				expect( conform.field_errors.test1.length ).to.equal( 1 )
				done()

		it 'not-ed delayed error with continuity', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'~test_fn.delay_reject &test_fn.delay_mutate'
				test2:'test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { test1: 'moebob', test2: 'suebob' } )
				expect( conform.errors.length ).to.equal( 0 )
				done()

		it 'break all', (done)->
			conform = new Conform({test1:'moe', test2:'sue'})
			rules =
				test1:'!!test_fn.delay_reject'
				test2:'test_fn.delay_mutate'
			conform.fields_rules(rules).then (o)->
				expect( o ).to.deep.equal( { } )
				expect( conform.errors.length ).to.equal( 1 )
				done()