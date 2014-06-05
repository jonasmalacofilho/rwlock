class Benchmark {

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
