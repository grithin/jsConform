###
An input validation tool stems from the fact most input validation logic is simple and conforming, and can be condensed beyond what PL offers in normal logic and conditions. to something that both reduces verbosity and encourages conformity to standard handling.

Why?
-	combination of filtering and validation
-	better, more concise, rule specification
	-	any function a rule, in global or instance scope
-	concise, flexible rule chain logic
	-	optional, break, break all, continuity, full continuity, not
-	promise handling


rule format
-	string only: `prefix + fn_path + '|' + param1 + ';' + param2`
-	flexible parameters: `[prefix + fn_path`, param1, param2,...]`
-	anonymous function: `[[prefix, fn], param1, param2,...]`

-	Function Input
	-	`(value, param1,...paramN, {field, instance, input, output})` obj w/ field and instance is appended to param list. Consequently, function should have a fixed number of parameters, so as not to confuse context obj with a parameter
	-	the instance, having a map of the input, can be changed within the function, but the current field value does not depend upon the instance `@input`.  Instead, it depends only upon the previous return values.  You can, however, affect the intial value of subsequent fields by changing `@input`
-	Function output
	-	always return the value, even if not modified
	-	throw an error if validation failed


compbiled rule ex
	rule =
		flags:
			not: true
			optional: true
			break: true
			break_all: true
			continuity: true
			full_continuity: true
		fn_path: ''
		params: []



Uses `Skip` for conform errors

###


###
@NOTE	editing `.input` and `.output`:
-	change of `.input` will affect subsequent calls on different fields
-	change of `.output` useful for changing a field that has already had its rules called
-	the return of a conform rule affects the input of subsequent rules for that same field

###

global.Conform = (input)->
	@input = _.cloneDeep input
	@errors = []
	@field_errors = {}
	@


Conform::v = {} # for instance level validation rules

# utility function creating rules that just return the original values.  Good for field filtering
Conform::make_pass_rules = (fields)->
	rules = {}
	for field in fields
		rules[field] = [@compile_rule '_.identity']


###
@RETURN	the conformed input.  If there was an error, it will still return the conformed input up until the point where the error stopped the conformaiton.
@NOTE	to determine if there was an error, use the `conform` instance; either `conform.errors` or `conform.field_errors.FIELD_NAME`
###
Conform::fields_rules = (field_map)->
	promise_fns = []
	# attach `output` to `this` so subsequent field rulesets can access new formatted values
	@output = output = {}

	for field, rules of field_map
		do (field, rules)=>
			promise_fns.push ()=>
				rules = @compile_rules(rules)
				@apply_rules(field, rules).then((v)-> output[field] = v).catch (e)->
					if e.type == 'break field' # expected in normal operation
						return
					throw e

	Promise.sequence(promise_fns).then(()-> output).catch (e)->
		if e.type == 'break all' # expected in normal operation
			return output
		throw e
Conform::field_rules = (field, rules)->
	rules = @compile_rules(rules)
	@apply_rules(field, rules)

Conform::compile_rules = (rules)->
	compiled_rules = []
	if a.string(rules)
		rules = rules.split(/[\s,]+/)
		rules = _.remove(rules) # remove empty rules, probably unintended by spacing after or before
	for rule in rules
		compiled_rules.push @compile_rule rule
	compiled_rules
Conform::compile_rule = (rule)->
	rule_obj = {}
	if a.string(rule)
		parsed_rule = @parse_rule_text(rule)
		rule_obj.flags = @parse_flags(parsed_rule.flag_string)
		rule_obj.params = @parse_params(parsed_rule.params_string)
		rule_obj.fn_path = parsed_rule.fn_path
		return rule_obj
	else if a.array(rule)
		if a.string rule[0]
			parsed_rule = @parse_rule_text(rule[0])
			rule_obj.flags = @parse_flags(parsed_rule.flag_string)
			rule_obj.fn_path = parsed_rule.fn_path
		else if a.array(rule[0])
			rule_obj.flags = @parse_flags(rule[0][0])
			rule_obj.fn_path = rule[0][1]
		else
			throw new Skip(message:'Non conforming rule', rule: rule)
		rule_obj.params = rule[1..]
		return rule_obj

Conform::apply_rules = (field, rules)->
	value = _.get(@input, field)
	@field_errors[field] = @field_errors[field] || []

	promise_fns = []
	for rule in rules
		do (rule)=>
			catch_fn = (e, value)=>
				if rule.flags.not && e.type != 'not' # potentially, the not flag caused the Error
					return value # must return the value so the sequence can continue with last-value
				if !rule.flags.optional
					error = {e:e, field:field, rule:rule}
					@field_errors[field].push error
					@errors.push error
				if rule.flags.break
					throw new Skip(type:'break field')
				if rule.flags.break_all
					throw new Skip(type:'break all')
				return value # rule was optional and non-breaking.  Return value for last-value on next rule
			promise_fns.push (value)=>
				# handle continuity
				if rule.flags.continuity && @field_errors[field].length
					throw new Skip(type:'break field')
				else if rule.flags.full_continuity && @errors.length
					throw new Skip(type:'break field')

				# resolve and try function
				fn = @resolve_fn(rule.fn_path)
				fn = _.partial.apply(_,[fn].concat [value].concat(rule.params)) # prefix fn with parameters
				fn = _.partialRight(fn, {field:field, instance:@, input:@input, output:@output}) # affix fn with context
				Promise.try(
					()->
						fn()
				).then(
					(v)->
						if rule.flags.not
							throw new Skip(type:'not')
						v
				).catch(_.partialRight catch_fn, value)
	Promise.sequence(promise_fns, value)

Conform::resolve_fn = (fn_path)->
	fn = _.get(@, fn_path)
	if !fn
		fn = _.get(global, fn_path)
	if !a.function(fn)
		throw new Error(['rule fn not a fn', fn_path])
	fn

Conform::parse_rule_text = (text)->
	match = text.match(/(^[^_a-z]+)?([^|]+)(\|(.*))?/i)
	if !match
		throw new Error('Rule text not conforming: "'+text+'"')
	return {
		flag_string: match[1]
		fn_path: match[2]
		params_string: match[4]
	}
# @return always array
Conform::parse_params = (params_string)->
	params_string && params_string.split(';') || []
Conform::parse_flags = (flag_string)->
	if !flag_string
		return {}
	# handle 2 char flags
	flags = {}
	if flag_string.match /\!\!/
		flags.break_all = true
		flag_string = flag_string.replace /\!\!/
	if flag_string.match /\&\&/
		flags.full_continuity = true
		flag_string = flag_string.replace /\&\&/
	for char in flag_string
		switch char
			when '?' then flags.optional = true
			when '!' then flags.break = true
			when '&' then flags.continuity = true
			when '~' then flags.not = true
	flags

Conform::transform_falses = (obj)->
	new_obj = {}
	_.each obj, (fn, k)=>
		if a.function(fn)
			new_obj[k] = @transform_false(fn)
	new_obj
Conform::transform_false = (fn)->
	()->
		value = arguments[0]

		Promise.dig(_.partial.apply(_,[fn].concat(Array.from(arguments)))()).then (v)->
			if !v
				throw new Skip(note:'transformed false function')
			value
Conform::standardise_errors = (errors)->
	errors = errors || @errors
	formed_errors = []
	# error = {e:e, field:field, rule:rule}
	# e being some thrown error, potentially a Skip or Error object
	for error in errors
		# special handling of not-ed rules
		if error.e instanceof Skip && error.e.type == 'not'
			formed = type: '~' + error.rule.fn_path
		else
			if error.e instanceof Skip # assume thrown Skip contains expected attributes (message, etc)
				formed = error.e.extract()
			else
				formed = {message:error.e.message}

		# apply defaults
		formed = _.defaults(formed, {fields:[error.field], type:error.rule.fn_path, params:error.rule.params})

		# ensure there's a message
		if !formed.message
			formed.message = formed.type

		formed_errors.push formed

	formed_errors
# Set up standard `is` validation
Conform::a = Conform::transform_falses(a)
# sometimes it is convenient to consider a string a number, and `is.above` does not allow that, so overwrite
was =
	above: Conform::a.above
	under: Conform::a.under
Conform::a.above = (x, y)->
	was.above(_.toNumber(x), _.toNumber(y))
Conform::a.under = (x, y)->
	was.under(_.toNumber(x), _.toNumber(y))

Conform::to =
	Date: (x)->
		new Date(x)
	moment: (x)->
		Time.from_guess(x)
