namespace Boo.OMeta

import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.PatternMatching

class OMetaMacroProcessor:
	
	ometa as MacroStatement
	options = []
	
	def constructor(ometa as MacroStatement):
		self.ometa = ometa
		self.options = ometa["options"] or []
		
	def expandGrammarSetup():
		block = Block()
		for e in expressions():
			match e:
				case [| $(ReferenceExpression(Name: name)) = $pattern |]:
					expandRule block, name, pattern
					
				case [| $(ReferenceExpression(Name: name))[$arg] = $pattern |]:
					expandRule block, name, pattern, arg
		return block
		
	def introduceRuleMethods(type as TypeDefinition):
		for stmt in ometa.Block.Statements:
			match stmt:
				case ExpressionStatement(Expression: [| $(ReferenceExpression(Name: name)) = $_ |]):
					m1 = [|
						def $name(input as OMetaInput):
							return Apply($name, input)
					|]
					type.Members.Add(m1)
					m2 = [|
						def $name(input as System.Collections.IEnumerable):
							return Apply($name, OMetaInput.For(input))
					|]
					type.Members.Add(m2)
					
				case ExpressionStatement(Expression: [| $(ReferenceExpression(Name: name))[$arg] = $_ |]):
					m1 = [|
						def $name(input as OMetaInput, $arg):
							return Apply($name, OMetaInput.ForArgument($arg, input))
					|]
					type.Members.Add(m1)
					m2 = [|
						def $name(input as System.Collections.IEnumerable, $arg):
							return Apply($name, OMetaInput.ForArgument($arg, OMetaInput.For(input)))
					|]
					type.Members.Add(m2)
					
				case DeclarationStatement(Declaration: Declaration(Name: name, Type: null), Initializer: block=BlockExpression()):
					m = Method(
							Name: name,
							LexicalInfo: block.LexicalInfo,
							Body: block.Body,
							Parameters: block.Parameters,
							ReturnType: block.ReturnType)
					
					type.Members.Add(m)
		
	def expandType():
		declaration = ometa.Arguments[0]
							
		type = [|
			class $(grammarName(declaration))(OMetaGrammar):
				
				_grammar as OMetaGrammar
					
				def constructor():
					_grammar = $(prototypeFor(declaration))
					$(expandGrammarSetup())
					
				def InstallRule(ruleName as string, rule as OMetaRule):
					_grammar.InstallRule(ruleName, rule)
			
				def OMetaGrammar.Apply(context as OMetaGrammar, rule as string, input as OMetaInput):
					return _grammar.Apply(context, rule, input)
					
				def OMetaGrammar.SuperApply(context as OMetaGrammar, rule as string, input as OMetaInput):
					return _grammar.SuperApply(context, rule, input)
					
				def Apply(rule as string, input as OMetaInput):
					return _grammar.Apply(self, rule, input)
					
				def Apply(rule as string, input as System.Collections.IEnumerable):
					return Apply(rule, OMetaInput.For(input))
				
		|]
		
		introduceRuleMethods type
		introduceGrammarParameters type
		
		type.LexicalInfo = ometa.LexicalInfo
		return type
		
	def introduceGrammarParameters(type as TypeDefinition):
		mie = ometa.Arguments[0] as MethodInvocationExpression
		if mie is null: return
		
		for arg in mie.Arguments:
			match arg:
				case r=ReferenceExpression():
					introduceGrammarParameter type, r, null
					
				case [| $paramName as $paramType |]:
					introduceGrammarParameter type, paramName, paramType
					
	def introduceGrammarParameter(type as TypeDefinition, name as ReferenceExpression, paramType as TypeReference):
		type.Members.Add(Field(Name: name.Name, Type: paramType))
		ctor = type.GetConstructor(0)
		ctor.Parameters.Add(ParameterDeclaration(Name: name.Name, Type: paramType))
		ctor.Body.Add([| self.$name = $name |])
			
	def expressions():
		for stmt in ometa.Block.Statements:
			match stmt:
				case ExpressionStatement(Expression: e):
					yield e
				otherwise:
					pass
					
	def expandRule(block as Block, name as string, pattern as Expression, *args as (Expression)):
		code = [|
			block:
				InstallRule($name) do(context as OMetaGrammar, input_ as OMetaInput):
					//print "> ${$name}"
					//try:
						$(OMetaMacroRuleProcessor(name, options).expand(pattern, args))
					//ensure:
					//	print "< ${$name}"
		|].Block
		block.Add(code)
	
def prototypeFor(e as Expression) as MethodInvocationExpression:
	match e:
		case [| $_ < $prototype |]:
			return [| OMetaDelegatingGrammar($prototype()) |]
		case ReferenceExpression():
			return [| OMetaGrammarPrototype() |]
		case [| $_() |]:
			return [| OMetaGrammarPrototype() |]
	
def grammarName(e as Expression) as string:
	match e:
		case [| $target() |]:
			return grammarName(target)
		case ReferenceExpression(Name: name):
			return name
		case [| $l < $_ |]:
			return grammarName(l)

def uniqueName():
	return ReferenceExpression(Name: "temp${CompilerContext.Current.AllocIndex()}")