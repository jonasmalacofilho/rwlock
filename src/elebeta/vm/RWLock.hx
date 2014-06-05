package elebeta.vm;

import haxe.CallStack.StackItem;

#if neko
import neko.vm.*;
#elseif cpp
import cpp.vm.*;
#end

/**
	Readers-writer lock for Haxe/Neko.
**/
class RWLock {
	
	/**
		Maximum number of allowed simultaneously users.
	**/
	public var maxReaders( default, null ):Int;

	/**
		Time before logging starvation of no-timeout resource acquirements.
	**/
	public var waitLogTimeout( default, null ):Float;

	/**
		Creates a read/write lock with [_maxReaders] simultaneous users.
		Params:
			[_maxReaders]:       maximum number of allowed simultaneously users.
			?[_waitLogTimeout]:  time in seconds before logging starvation of
			                     no-timeout resource acquirements; default is 1
			                     second.
			?[_waitLogger]:      logger for starvation of no-timeout requests;
			                     should receive a call stack array and the time
			                     spent so far; defaults to tracing the current
			                     spent time.
		Returns:
			A new and unused (no readers and no writers) read/write lock.
	**/
	public function new( _maxReaders:Int, ?_waitLogTimeout:Null<Float>
	, ?_waitLogger:Array<StackItem>->Float->Void ) {
		maxReaders = _maxReaders;
		waitLogTimeout = _waitLogTimeout != null ? _waitLogTimeout : 1.;
		if ( _waitLogger != null ) waitLogger = _waitLogger;		
		semaphore = new Lock();
		mutex = new Mutex();
		releaseAll();
	}


	/**
		HIGH LEVEL PUBLIC API.
	**/


	/**
		Executes a "read only" procedure.

		Params:
			[callb]:  procedure to be executed; it cannot require locking (for
			          reading or writing) the current lock; it should not also
			          require locking other resources and it should complete
			          in a reasonable amount of time, since while there are any
			          active readers no writes are authorized.
			?[wait]:  timeout for acquiring a "read" level authorization.
		Returns:
			[true] if the [callb] function was executed.
	**/
	public function read( callb:Void->Void, ?wait:Null<Float> ):Bool {
		if ( acquire( wait ) ) {
			callb();
			release();
			return true;
		}
		return false;
	}

	/**
		Executes a write procedure.

		Params:
			[callb]:  procedure to be executed; it cannot require locking (for
			          reading or writing) the current lock; it should not also
			          require locking other resources and it should complete
			          in a reasonable amount of time, since while there are any
			          active readers no writes are authorized.
			?[wait]:  timeout for acquiring a "write" level authorization.
		Returns:
			[true] if the [callb] function was executed.
	**/
	public function write( callb:Void->Void, ?wait:Null<Float> ):Bool {
		if ( acquireAll( wait ) ) {
			callb();
			releaseAll();
			return true;
		}
		return false;
	}


	/**
		LOW LEVEL PUBLIC API.
	**/


	/**
		Prepares for reading, that is, acquire one resource unit.

		Params:
			?[wait]:  timeout for acquiring the resource.
		Returns:
			[true] if the resource was successfully acquired.
	**/
	public function prepareRead( ?wait:Null<Float> ):Bool {
		return acquire( wait );
	}

	/**
		Marks reading as completed, that is, releases one resource unit.
	**/
	public function releaseRead() {
		release();
	}

	/**
		Prepares for writing, that is, acquire all resource unit.

		Params:
			?[wait]:  timeout for acquiring the resource.
		Returns:
			[true] if the resources were successfully acquired.
	**/
	public function prepareWrite( ?wait:Null<Float> ):Bool {
		return acquireAll( wait );
	}

	/**
		Marks writing as completed, that is, releases all resource unit.
	**/
	public function releaseWrite() {
		releaseAll();
	}

	/**
		Converts a read into a write operation;
		Prepares for writing but only acquiring (all - 1) resources units,
		since one should already be owned by the calling method.

		Params:
			?[wait]:  timeout for acquiring the resource.
		Returns:
			[true] if the resources were successfully acquired.
	**/
	public function convertToWriting( ?wait:Null<Float> ):Bool {
		return acquireAll( wait, 1 );
	}

	public function backToReading() {
		releaseAll( 1 );
	}


	/**
		INTERNAL (LOWEST LEVEL) API.
		To expose these basic methods the RWLOCK_SUPER directive should
		be defined at compilation.
	**/

	/**
		Logger for starvation of no-timeout requests; can be dynamically
		rebinded at constrution.
		
		Params:
			[cs]:  current call stack (array); this is the output of
			       haxe.CallStack.callStack().
			[ts]:  time spent so far in seconds.
	**/
	dynamic function waitLogger( cs:Array<StackItem>, ts:Float ) {
		trace( "Waiting too much (" + ts + " seconds) to acquire resource(s):"
		+ haxe.CallStack.toString( cs ) );
	}

	/**
		Semaphore, used mainly for controlling readers.
	**/
	var semaphore:Lock;

	/**
		Mutex, used to prevent writer thread deadlock.
	**/
	var mutex:Mutex;

	/**
		Releases/frees one resource unit.
		Only available if RWLOCK_SUPER has been defined.
	**/
	#if RWLOCK_SUPER public #end inline function release():Void {
		semaphore.release();
	}

	/**
		Tries do acquire one resource unit, waiting up to [wait] seconds. If no
		timeout has been set, [waitLogger] is called every [waitLogTimeout]
		seconds.
		Only available if RWLOCK_SUPER has been defined.

		Parameters:
			[wait]:  Finite timeout or [null], that is, no timeout.
		Returns:
			[true] if the resource was successfully acquired.
	**/
	#if RWLOCK_SUPER public #end inline function acquire( ?wait:Null<Float> ):Bool {
		if ( wait != null )
			return semaphore.wait( wait );
		else {
			var ts = 0.; // time spent so far
			while ( !semaphore.wait( waitLogTimeout ) )
				waitLogger( haxe.CallStack.callStack(), ts += waitLogTimeout );
			return true;
		}
	}

	/**
		Releases all resources.
		Only available if RWLOCK_SUPER has been defined.
	**/
	#if RWLOCK_SUPER public #end function releaseAll( ?owned=0 ) {
		for ( i in 0...( maxReaders - owned ) )
			release();
	}

	/**
		Tries to acquire all resources, waiting up to [wait] seconds. To prevent
		deadlocks (when to threads try to simultaneously acquire all resources),
		this operation is encapsulated by a mutex.
		Only available if RWLOCK_SUPER has been defined.

		Parameters:
			?[wait]:   Finite timeout or [null], that is, no timeout.
			?[owned]:  Number of already owned resources (that do not need to be
			           acquired again).
		Returns:
			[true] if all resources were successfully acquired.
	**/
	#if RWLOCK_SUPER public #end function acquireAll( ?wait:Null<Float>
	, ?owned=0 ):Bool {
		// remaining timeout/wait
		var timeout = wait;
		// acquire the anti-deadlock mutex
		mutex.acquire();
		for ( i in 0...( maxReaders - owned ) ) {
			var t0 = timestamp();
			// try to acquire one resource
			var res = acquire( timeout );
			// resource acquired?
			if ( res ) {
				// resource successfully acquired
				// update remaining timeout/wait
				if ( timeout != null )
					timeout -= timestamp() - t0;
			}
			else {
				// resource was not acquired
				// free acquired resources
				for ( j in 0...i )
					release();
				// release the anti-deadlock mutex
				mutex.release();
				// return failure
				return false;
			}
		}
		// release the anti-deadlock mutex
		mutex.release();
		// return success
		return true;
	}

	
	/**
		COMPLEMENTARY DEFINITIONS.
	**/


	/**
		Compare-only type timestamp, in seconds.
	**/
	inline function timestamp() {
		return haxe.Timer.stamp();
	}

}
