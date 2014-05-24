import sys.vm.ReadWriteLock;
import neko.vm.Thread;

class TestReadWriteLock {

	static function status( msg:String ) {
		Sys.stdout().writeString( "\r" + msg );
	}

	static function statusln( msg:String ) {
		status( msg + "\n" );
	}

	static function main() {

		haxe.Log.trace = function ( msg, ?pos )
			Sys.stdout().writeString( "\n..." + msg + "\n" );

		status( "Creating a lock..." );
		var lk = new ReadWriteLock( 2, 1.
		, function ( cs, ts ) {
			if ( ts < 3.5 )
				statusln( "...alread waited "+ts+" seconds to acquire this resource" );
			else
				throw "done";
		} );
		statusln( "Creating a lock... Done." );

		status( "Acquiring all resouces..." );
		lk.prepareWrite();
		statusln( "Acquiring all resouces... Done." );

		statusln( "Tyring to acquire one more resource" );
		try {
			lk.prepareRead();
		}
		catch ( e:String ) {
			if ( e != "done" )
				neko.Lib.rethrow( e );
		}
		statusln( "Tyring to acquire one more resource... Done." );

		statusln( "Begin unit testing..." );
		var t = new haxe.unit.TestRunner();
		t.add( new BasicTest() );
		t.add( new ThreadedTest() );
		t.run();
		statusln( "Done unit testing." );

	}

}

private class BasicTest extends haxe.unit.TestCase {

	public function testHighLevelRead() {
		var calls = 0;
		var f = function () calls++;

		var lk = new ReadWriteLock( 1 );
		assertTrue( lk.read( f, 0 ) );
		assertEquals( 1, calls );
		/* internal */ lk.acquire();
		assertFalse( lk.read( f, 0 ) );
		assertEquals( 1, calls );
		/* internal */ lk.release();

		calls = 0;
		lk = new ReadWriteLock( 2 );
		assertTrue( lk.read( f, 0 ) );
		assertEquals( 1, calls );
		/* internal */ lk.acquire();
		assertTrue( lk.read( f, 0 ) );
		assertEquals( 2, calls );
		/* internal */ lk.release(); lk.acquireAll();
		assertFalse( lk.read( f, 0 ) );
		assertEquals( 2, calls );
		lk.releaseAll();
	}

	public function testHighLevelWrite() {
		var calls = 0;
		var f = function () calls++;

		var lk = new ReadWriteLock( 1 );
		assertTrue( lk.write( f, 0 ) );
		assertEquals( 1, calls );
		/* internal */ lk.acquire();
		assertFalse( lk.write( f, 0 ) );
		assertEquals( 1, calls );
		/* internal */ lk.release();
	}

	public function testLowerLevelRead() {
		var lk = new ReadWriteLock( 2 );
		assertTrue( lk.prepareRead( 0 ) );
		assertTrue( lk.prepareRead( 0 ) );
		assertFalse( lk.prepareRead( 0 ) );
		lk.releaseAll();

		assertTrue( lk.prepareRead( 0 ) );
		assertTrue( lk.prepareRead( 0 ) );
		lk.releaseAll();
	}

	public function testLowerLevelWrite() {
		var lk = new ReadWriteLock( 2 );
		assertTrue( lk.prepareWrite( 0 ) );
		assertFalse( lk.prepareWrite( 0 ) );
		assertFalse( lk.prepareRead( 0 ) );
		lk.releaseAll();

		assertTrue( lk.prepareWrite( 0 ) );
		lk.releaseAll();
	}

	public function testLowerLevelReadThenWrite() {
		var lk = new ReadWriteLock( 2 );
		assertTrue( lk.prepareRead( 0 ) );
		assertTrue( lk.prepareRead( 0 ) );
		lk.release();
		assertTrue( lk.convertToWriting( 0 ) );
		assertFalse( lk.prepareRead( 0 ) );
		lk.releaseAll();

		assertTrue( lk.prepareRead( 0 ) );
		assertTrue( lk.prepareRead( 0 ) );
		lk.releaseAll();
	}

}

private class ThreadedTest extends haxe.unit.TestCase {

	var t1:Thread;
	var t2:Thread;
	var t3:Thread;

	override public function setup() {
		t1 = Thread.create( worker );
		t1.sendMessage( Thread.current() );
		t2 = Thread.create( worker );
		t2.sendMessage( Thread.current() );
		t3 = Thread.create( worker );
		t3.sendMessage( Thread.current() );
	}

	override public function tearDown() {
		t1.sendMessage( Retire );
		t2.sendMessage( Retire );
		t3.sendMessage( Retire );
		Thread.readMessage( true );
		Thread.readMessage( true );
		Thread.readMessage( true );
	}

	function worker() {
		var parent:Thread = Thread.readMessage( true );
		while ( true ) {
			var command:Command = Thread.readMessage( true );
			switch ( command ) {
				case F( f ): f();
				case Retire:
					parent.sendMessage( true );
					return;
			}
		}
	}

	// some multithreaded tests should go here

}

private enum Command {
	F( f:Void->Void );
	Retire;
}
