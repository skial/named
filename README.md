Named
=====

An experimental named parameters implementation using build macros.

## Install

`haxelib git named https://github.com/skial/named.git`

And add `-lib named` to your `hxml` file.
	
## Usage

You have two options, use Named with [Klas](https://github.com/skial/klas/) or not.

#### With Klas

```
package ;

class Main implements Klas {
	
	public function new() {
		var result = long(@:g 'World', @b 'Hello');
	}
	
	public function long(?a:String, ?b:String, ?c:String, ?d:String, ?e:String, ?f:String, ?g:String):String {
		// Do something.
	}
	
}
```

#### Without Klas

```
package ;

@:autoBuild( uhx.macro.NamedArgs.build() )
class Main {
	
	public function new() {
		var result = long(@:g 'World', @b 'Hello');
	}
	
	public function long(?a:String, ?b:String, ?c:String, ?d:String, ?e:String, ?f:String, ?g:String):String {
		// Do something.
	}
	
}
```

## Explanation

An experiment to implement named parameters using a build macro.

+ You can use either style of meta tags, runtime `@name` or compile
time `@:name`, it doesn't matter.
+ You have to name the meta tag the same as the parameter name.
+ It can be used with both optional or non optional parameters.

## Tests

You can find Named tests in the [uhu-spec](https://github.com/skial/uhu-spec/blob/master/src/uhx/macro/NamedArgsSpec.hx) library.