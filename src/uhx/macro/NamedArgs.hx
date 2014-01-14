package uhx.macro;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import uhx.macro.KlasImpl;

using StringTools;
using uhu.macro.Jumla;

/**
 * ...
 * @author Skial Bainn
 */
class NamedArgs {
	
	private static function initialize() {
		try {
			if (!KlasImpl.setup) {
				KlasImpl.initalize();
			}
			
			KlasImpl.DEFAULTS.push(NamedArgs.handler);
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.macro.NamedArgs.build()` method.
		}
	}

	public static function build():Array<Field> {
		return handler( Context.getLocalClass().get(), Context.getBuildFields() );
	}
	
	public static function handler(cls:ClassType, fields:Array<Field>):Array<Field> {
		
		for (field in fields) {
			
			switch (field.kind) {
				
				case FFun(method):
					
					method.expr = loop( method.expr );
					
				case _:
				
			}
			
		}
		
		return fields;
	}
	
	private static function paramSub(type:Type, params:Array<Expr>):Array<Expr> {
		var result:Array<Expr> = [];
		var matches:Array<{e:Expr, n:String, pos:Int}> = [];
		var args = type.args();
		var arity = type.arity();
		
		for (i in 0...arity) {
			if (args[i].opt) break;
			// I consider this a poor check, but it works.
			if (!args[i].opt && (params[i] == null || params[i].expr.getName() == 'EMeta')) return params;
		}
		
		for (i in 0...arity) {
			var e = macro null;
			if (params[i] != null && params[i].expr.getName() != 'EMeta') {
				e = params[i];
			}
			result.push( e );
		}
		
		for (i in 0...params.length) {
			
			var val:Expr = params[i];
			
			if (val.expr.getName() == 'EMeta') {
				
				//var type = expr.printExpr().find();
				
				var meta:MetadataEntry = val.expr.getParameters()[0];
				var name:String = meta.name.replace(':', '');
				
				//result[ args.indexOf( name ) ] = val.expr.getParameters()[1];
				matches.push( { e: val, n: name , pos: args.find( name ) } );
				
				//copy = copy.splice(0, i).concat( copy.splice(i + 1, -1) );
				
			}
			
		}
		
		for (match in matches) {
			
			if (match.pos == -1) {
				trace( match );
			}
			
			/*while (match.pos > copy.length - 1) {
				
				copy.push(macro null);
				
			}*/
			
			//copy[match.pos] = match.e.expr.getParameters()[1];
			result[match.pos] = match.e.expr.getParameters()[1];
			
		}
		
		if (matches.length == 0) result = params;
		
		return result;
	}
	
	private static function loop(e:Expr):Expr {
		var result = e;
		
		switch (e.expr) {
			case EVars(vars):
				for (v in vars) {
					
					if (v.expr != null) {
						
						v.expr = loop( v.expr );
						
					}
					
				}
				
			case EArrayDecl(exprs):
				result = { expr: EArrayDecl( [for (expr in exprs) loop( expr )] ), pos: e.pos };
				
			case EBlock(exprs):
				result = { expr: EBlock( [for (expr in exprs) loop( expr )] ), pos: e.pos };
				
			case ECall(expr, params):
				var type = expr.printExpr().find();
				if (type != null) {
					result = { expr: ECall( expr, paramSub( type, params ) ), pos: e.pos };
				}
				
			case ENew(tpath, params):
				var type = '${tpath.path()}.new'.find();
				if (type != null) {
					result = { expr: ENew( tpath, paramSub( type, params ) ), pos: e.pos };
				}
				
			case _:
				//trace( e );
		}
		
		return result;
	}
	
}