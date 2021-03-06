namespace UnityScript.MonoDevelop.ProjectModel

import System
import System.IO

import MonoDevelop.Projects
import MonoDevelop.Ide.TypeSystem

import ICSharpCode.NRefactory.CSharp

import Boo.MonoDevelop.Util
import UnityScript.MonoDevelop

class UnityScriptParser(TypeSystemParser):
	
	public static final MimeType = "text/x-unityscript"
	
	def constructor():
		super()
		
#	override def CanParse(fileName as string):
#		return IsUnityScriptFile(fileName)
		
	override def Parse(storeAst as bool, fileName as string, reader as TextReader, project as Project):
		result = ParseUnityScript(fileName, reader.ReadToEnd ())
		document = DefaultParsedDocument(fileName, Ast: SyntaxTree (FileName: fileName))
		
		try:
			result.CompileUnit.Accept(DomConversionVisitor(document.GetAst of SyntaxTree ()))
		except e:
			LogError e
		
		return document
		
def ParseUnityScript(fileName as string, content as string):
	compiler = UnityScript.UnityScriptCompiler()
	compiler.Parameters.ScriptMainMethod = "Awake"
	compiler.Parameters.ScriptBaseType = object
	compiler.Parameters.Pipeline = UnityScript.UnityScriptCompiler.Pipelines.Parse()
	compiler.Parameters.Input.Add(Boo.Lang.Compiler.IO.StringInput(fileName, content))
	return compiler.Run()
	