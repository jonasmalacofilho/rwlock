import sys.vm.ReadWriteLock;
import Math.random;
import neko.vm.Thread;
import neko.vm.Lock;

class Test {

    // THE LOCK!
    var lockCap : Int;
    var lock : ReadWriteLock;

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

        lock = new ReadWriteLock(lockCap, 1., function (stack, time) null);
        spawnWorkers();
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
        Thread.create(countPrinter);
    }

    function countPrinter() {

        function sum(it : Iterable<Float>)
            return Lambda.fold(it, function (x, acc) return acc + x, 0.);

        var step = 0;
        var epoch = haxe.Timer.stamp();

        var timer = new Timer();
        while (true) {
            var elapsed = Math.round(1e3*(haxe.Timer.stamp() - epoch));
            var r = "reads at: " + sum([for (worker in readers) worker.getCount()]);
            var w = "writes at: " + sum([for (worker in writers) worker.getCount()]);
            Sys.print('STEP ${step++} (after ${elapsed} ms):\n\t$r\n\t$w\n');
            timer.wait(1);
        }

    }

}

class Perf {

    static function main() {
        var args = Sys.args();
        var lockCap = Std.parseInt(args[0]);
        var noReaders = Std.parseInt(args[1]);
        var noWriters = Std.parseInt(args[2]);
        var x = new Test(lockCap, noReaders, noWriters, .5, .5, .05, .2);
        x.run();
        var timer = new Timer();
        timer.wait();
    }

}

class Worker {

    var lock : ReadWriteLock;
    var prob : Float;
    var time : Float;
    var write : Bool;
    var opCnt = 0;
    var timer = new Timer();

    public
    function new(lock, prob, time, write) {
        this.lock = lock;
        this.prob = prob;
        this.time = time;
        this.write = write;
    }

    public
    function run() {
        while (true) {
            var t = (random() <= prob) ? op() : 0.;
            timer.wait(t/prob - t);  // prob = time/total_time
        }
    }

    public
    function getCount() {
        return opCnt;
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

@:publicFields
class Timer {

    var aux = new Lock();

    // t in ms
    function wait(?t : Null<Float>) {
        aux.wait(t);
    }

}
