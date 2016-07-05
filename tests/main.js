(function() {
  var expect;

  expect = require('chai').expect;

  global.root_path = '/www/self/mapodofu';

  require('coffee-script/register');

  require(root_path + '/loader_base');

  global.test_fn = {
    pass: function(v) {
      return v;
    },
    delay_pass: function(v) {
      return Promise.delay(200).then(function() {
        return v;
      });
    },
    mutate: function(v) {
      return v + 'bob';
    },
    delay_mutate: function(v) {
      return Promise.delay(200).then(function() {
        return v + 'bob';
      });
    },
    reject: function(v) {
      throw new Error('fail');
    },
    delay_reject: function(v) {
      return Promise.delay(200).then(function() {
        throw new Error('fail');
      });
    }
  };


  /*
  conform = new Conform({test1:'moe', test2:'sue'})
  rules =
  	test1:'~test_fn.delay_reject &test_fn.delay_mutate'
  	test2:'test_fn.delay_mutate'
  conform.fields_rules(rules).then (o)->
  	c o
  	c conform.errors
   */

  describe("Test Suite", function() {
    this.timeout(10000);
    it("rules string separation", function() {
      return expect(Conform.prototype.compile_rules('bob bob, bob ,bob , bob').length).to.equal(5);
    });
    describe(".compile_rule", function() {
      it('!a.string', function() {
        return expect(Conform.prototype.compile_rule('!a.string')).to.deep.equal({
          flags: {
            "break": true
          },
          params: [],
          fn_path: 'a.string'
        });
      });
      it('!!a.string', function() {
        return expect(Conform.prototype.compile_rule('!!a.string')).to.deep.equal({
          flags: {
            break_all: true
          },
          params: [],
          fn_path: 'a.string'
        });
      });
      it('?!a.above|10', function() {
        return expect(Conform.prototype.compile_rule('?!a.above|10')).to.deep.equal({
          flags: {
            optional: true,
            "break": true
          },
          params: ['10'],
          fn_path: 'a.above'
        });
      });
      return it('~?&&a.function', function() {
        return expect(Conform.prototype.compile_rule('~?&&a.function')).to.deep.equal({
          flags: {
            full_continuity: true,
            not: true,
            optional: true
          },
          params: [],
          fn_path: 'a.function'
        });
      });
    });
    return describe("validation", function() {
      it('mutate', function(done) {
        var conform;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        return conform.fields_rules({
          test1: 'test_fn.pass test_fn.mutate',
          test2: 'test_fn.pass test_fn.mutate'
        }).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebob',
            test2: 'suebob'
          });
          return done();
        });
      });
      it('mutates', function(done) {
        var conform;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        return conform.fields_rules({
          test1: 'test_fn.pass test_fn.mutate test_fn.mutate',
          test2: 'test_fn.pass test_fn.mutate test_fn.mutate'
        }).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebobbob',
            test2: 'suebobbob'
          });
          return done();
        });
      });
      it('delayed_mutates', function(done) {
        var conform;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        return conform.fields_rules({
          test1: 'test_fn.pass test_fn.delay_mutate test_fn.delay_mutate',
          test2: 'test_fn.pass test_fn.delay_mutate test_fn.delay_mutate'
        }).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebobbob',
            test2: 'suebobbob'
          });
          return done();
        });
      });
      it('reject', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: 'test_fn.pass test_fn.reject test_fn.delay_mutate',
          test2: 'test_fn.pass test_fn.reject test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(conform.errors.length).to.equal(2);
          expect(conform.field_errors.test1.length).to.equal(1);
          expect(conform.field_errors.test2.length).to.equal(1);
          return done();
        });
      });
      it('delayed reject', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: 'test_fn.pass test_fn.delay_reject test_fn.delay_mutate',
          test2: 'test_fn.pass test_fn.delay_reject test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(conform.errors.length).to.equal(2);
          expect(conform.field_errors.test1.length).to.equal(1);
          expect(conform.field_errors.test2.length).to.equal(1);
          return done();
        });
      });
      it('optional reject', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: 'test_fn.pass ?test_fn.reject test_fn.delay_mutate',
          test2: 'test_fn.pass ?test_fn.reject test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebob',
            test2: 'suebob'
          });
          expect(conform.errors.length).to.equal(0);
          return done();
        });
      });
      it('optional delayed reject', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: 'test_fn.pass ?test_fn.delay_reject test_fn.delay_mutate',
          test2: 'test_fn.pass ?test_fn.delay_reject test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebob',
            test2: 'suebob'
          });
          expect(conform.errors.length).to.equal(0);
          return done();
        });
      });
      it('full continuity without error', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: '?!test_fn.reject',
          test2: '&&test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({
            test2: 'suebob'
          });
          return done();
        });
      });
      it('full continuity with error', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: '!test_fn.reject',
          test2: '&&test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({});
          return done();
        });
      });
      it('full continuity with delayed error', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: '!test_fn.delay_reject',
          test2: '&&test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({});
          return done();
        });
      });
      it('continuity with delayed error', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: 'test_fn.delay_reject &test_fn.delay_mutate',
          test2: 'test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({
            test2: 'suebob'
          });
          expect(conform.field_errors.test1.length).to.equal(1);
          return done();
        });
      });
      it('not-ed delayed error with continuity', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: '~test_fn.delay_reject &test_fn.delay_mutate',
          test2: 'test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({
            test1: 'moebob',
            test2: 'suebob'
          });
          expect(conform.errors.length).to.equal(0);
          return done();
        });
      });
      return it('break all', function(done) {
        var conform, rules;
        conform = new Conform({
          test1: 'moe',
          test2: 'sue'
        });
        rules = {
          test1: '!!test_fn.delay_reject',
          test2: 'test_fn.delay_mutate'
        };
        return conform.fields_rules(rules).then(function(o) {
          expect(o).to.deep.equal({});
          expect(conform.errors.length).to.equal(1);
          return done();
        });
      });
    });
  });

}).call(this);

//# sourceMappingURL=main.js.map
