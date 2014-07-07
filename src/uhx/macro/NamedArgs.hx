package uhx.macro;

import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import uhx.macro.KlasImp;

using Lambda;
using StringTools;
using uhx.macro.NamedArgs;
using haxe.macro.TypeTools;
using haxe.macro.ExprTools;
using haxe.macro.MacroStringTools;
using haxe.macro.ComplexTypeTools;

/**
 * ...
 * @author Skial Bainn
 */
class NamedArgs {
	
	private static function initialize() {
		try {
			KlasImp.initalize();
			//KlasImp.INLINE_META.set( ~/\([\s]*@:?[\d\w]+\s+[\d\w\.'"~\/\\=\\+-\|#@]+[\s,]*\)/, NamedArgs.handler );
			//KlasImp.INLINE_META.set( ~/@:?[\d\w]+\s+[\S]+[\s,]*/, NamedArgs.handler );
			KlasImp.INLINE_META.set( ~/([\s]*@:?[\w]+[\sa-zA-Z0-9.'"<=>\-,\?]*)([\s]*,|[\s]*\))/, NamedArgs.handler );
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.macro.NamedArgs.build()` method.
		}
	}
	
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		for (i in 0...fields.length) {
			fields[i] = handler( cls, fields[i] );
		}
		
		return fields;
	}
	
	public static function handler(cls:ClassType, field:Field):Field {
		
		switch (field.kind) {
			case FFun(method) if (method.expr != null): loop( method.expr, field );
			case _:
		}
		
		return field;
	}
	
	private static function loop(e:Expr, field:Field) {
		trace( new Printer().printExpr( e ) );
		switch (e) {
			case macro $ident($a { params } ):
				var type = e.resolve(field);
				
				if (type != null) {
					var results = paramSub( type, params );
					e.expr = Context.parse( '${new Printer().printExpr( ident )}(${results.map(function(r) return r.toString()).join(",")})', e.pos).expr;
				}
				
			case macro new $ident($a { params } ):
				var results = paramSub( Context.typeof(e).getClass().constructor.get().type, params );
				
				if (results != params) {
					e.expr = Context.parse( 'new ${ident.name}(${results.map(function(r) return r.toString()).join(",")})', e.pos).expr;
				}
				
			case _:
				e.iter( loop.bind(_, field) );
				
		}
	}
	
	private static function paramSub(caller:Type, params:Array<Expr>) {
		
		// First check `params` if any metadata exists
		var hasMeta = params.exists( function(p) return switch (p) {
			case { expr: EMeta(_, _), pos: _ } : true;
			case _: false;
		} );
		
		var results = params;
		
		if (hasMeta) {
			var args = switch(caller) {
				case TFun(args, _): args;
				case _: [];
			}
			var arity = args.length;
			var new_params = [for (i in 0...arity) macro null];
			var pos_map = [for (i in 0...arity) args[i].name => i];
			
			for (i in 0...params.length) switch (params[i]) {
				case { expr: EMeta(meta, expr), pos: pos } if (pos_map.exists( meta.name.replace(':', '') )):
					var name = meta.name.replace(':', '');
					new_params[ pos_map.get( name ) ] = expr;
					
				case _:
					new_params[i] = params[i];
			}
			
			results = new_params;
		}
		
		return results;
	}
	
	private static function resolve(expr:Expr, local:Field) {
		var type = null;
		
		switch (expr.expr) {
			case ECall(e, p):
				var parts = [];
				var extract:Expr->Void = null;
				extract = function(expr) switch (expr.expr) {
					case EConst( CIdent( ident ) ): parts.push( ident );
					case EField( e, f ):
						extract( e );
						parts.push( f );
						
					case ECall( e, p ):
						// This handles chained calls eg `m('a', 0)('b', 0)`
						extract( e );
						var type = expr.resolve(local);
						if (type != null) {
							var results = paramSub( type, p );
							expr.expr = Context.parse( '${parts.join(".")}(${results.map(function(r) return r.toString()).join(",")})', expr.pos).expr;
						}
						
					case _: e.iter( extract );
				}
				extract( e );
				
				// Check if it's a scoped variable
				var name = parts.join('.');
				
				switch (local.kind) {
					case FFun(m):
						var finder:Expr->Void = null;
						
						finder = function(e:Expr) {
							switch (e.expr) {
								case EVars(vars):
									for (v in vars) if (v.name.trim() == name) {
										type = v.type != null ?  v.type.toType() : Context.typeof( v.expr );
										break;
									}
									
								case _: 
									e.iter( finder );
							}
						}
						
						finder( m.expr );
						
					case _:
						
				}
				
				// Check local methods/properties for a match
				if (type == null) {
					var field = Context.getBuildFields().filter( function(f) return f.name == name )[0];
					
					if (field != null) type = switch (field.kind) {
						case FFun(m): TFun( [for (arg in m.args) { name:arg.name, opt:arg.opt, t:arg.type.toType() } ], m.ret.toType() );
						case FVar(t, _): t.toType().follow();
						case FProp(_, _, t, _): t.toType().follow();
					}
					
				}
				
				// Try and resolve the type by building a package, class and then by field
				if (type == null) {
					var pack = [];
					
					while (type == null && parts.length > 0) {
						var part = parts.shift();
						var name = pack.toDotPath( part );
						
						try {
							type = Context.getType( name );
						} catch (_e:Dynamic) {
							pack.push( part );
						}
					}
					
					if (type != null) {
						if (parts.length > 0) type = type.resolveField( parts );
					}
					
				}
				
			case _:
				trace( expr );
		}
		
		return type;
	}
	
	private static function resolveField(cls:Type, fields:Array<String>) {
		var result = cls;
		var cls = cls.getClass();
		
		while (fields.length > 0) {
			var field = fields.shift();
			
			var cfield = switch ([cls.findField( field ), cls.findField( field, true )]) {
				case [null, x] if (x != null): x;
				case [x, null] if (x != null): x;
				case _: null;
			}
			
			if (cfield != null) switch (cfield.type.follow()) {
				case TType(t, p):
					result = t.get().type.follow();
					
				case TInst(t, p):
					result = cfield.type.follow();
					cls = t.get();
					
				case TAnonymous(a):
					var afields = a.get().fields;
					
					while (fields.length > 0) {
						field = fields.shift();
						var filter = afields.filter( function(f) return f.name == field );
						if (filter.length > 0) {
							result = filter[0].type.follow();
						}
					}
					
				case _: 
					result = cfield.type.follow();
					
			} else {
				break;
			}
			
		}
		
		return result;
	}
	
	private static inline function isUpperCase(value:String):Bool {
		return value == value.toUpperCase();
	}
	
}