import Math.random;
import elebeta.vm.RWLock;

#if neko
import neko.vm.*;
#elseif cpp
import cpp.vm.*;
#end

class Test {

    // THE LOCK!
    var lockCap : Int;
    var lock : RWLock;

    // the scenario
    var noReaders : Int;
    var noWriters : Int;

    // probabilities of read/write events occuring in any given time interval 
    var probRead : Float;
    var probWrite : Float;  // probRead + probWrite != 1

    // duration of each event
    var readDur : Float;
    var writeDur : Float;

    var readers = [];
    var writers = [];

    public
    function new(lockCap, noReaders, noWriters, probRead, probWrite, readDur, writeDur) {
        this.lockCap = lockCap;
        this.noReaders = noReaders;
        this.noWriters = noWriters;
        this.probRead = probRead;
        this.probWrite = probWrite;
        this.readDur = readDur;
        this.writeDur = writeDur;
    }

    public
    function run() {
        // monitoring
        spawnHelpers();

        lock = new RWLock(lockCap, 1., function (stack, time) null);
        lock.prepareWrite();
        spawnWorkers();
        lock.releaseWrite();
    }

    public
    function getCounts() {
        function sum(it : Iterable<Float>) {
            return Lambda.fold(it, function (x, acc) return acc + x, 0.);
        }

        var reads = sum([for (worker in readers) worker.getCount()]);
        var writes = sum([for (worker in writers) worker.getCount()]);
        return [reads, writes];
    }

    public
    function kill() {
        var order = new KillOrder(noReaders + noWriters);
        for (reader in readers)
            reader.kill(order);
        for (writer in writers)
            writer.kill(order);
        order.wait();
    }

    function spawnOneWorker(prob, dur, write) {
        var worker = new Worker(lock, prob, dur, write);
        Thread.create(worker.run);
        return worker;
    }

    function spawnWorkers() {
        readers = [for (i in 0...noReaders) spawnOneWorker(probRead, readDur, false)];
        writers = [for (i in 0...noWriters) spawnOneWorker(probWrite, writeDur, true)];
    }

    function spawnHelpers() {
        // pass
    }

}

class Worker {

    var lock : RWLock;
    var prob : Float;
    var time : Float;
    var write : Bool;
    var opCnt = 0;
    var timer = new Timer();
    var killOrder:KillOrder;

    public
    function new(lock, prob, time, write) {
        this.lock = lock;
        this.prob = prob;
        this.time = time;
        this.write = write;
    }

    public
    function run() {
        while (killOrder == null) {
            var t = (random() <= prob) ? op() : 0.;
            timer.wait(t/prob - t);  // prob = time/total_time
        }
        killOrder.dying();
        killOrder = null;
    }

    public
    function getCount() {
        return opCnt;
    }

    public
    function kill(semaphore) {
        killOrder = semaphore;
    }

    function op() {
        var t = dist(time);
        if (write) {
            lock.prepareWrite();
            timer.wait(t);
            lock.releaseWrite();
        }
        else {
            lock.prepareRead();
            timer.wait(t);
            lock.releaseRead();   
        }
        opCnt++;
        return t;
    }

    function dist(expected : Float) {
        return random()*expected*2;
    }

}

class KillOrder {

    var lock = new Lock();
    var n:Int;

    public
    function new(n:Int) {
        this.n = n;
    }

    public
    function dying() {
        lock.release();
    }

    public
    function wait() {
        for (i in 0...n)
            lock.wait();
    }

}
