class Benchmark {

    static function main() {
        var args = Sys.args();
        var noReaders = 20;
        var noWriters = 2;
        var timer = new Timer();
        for (lockCap in 1...23) {
            var test = new Test(lockCap, noReaders, noWriters, 1, 1, .01, .02);
            test.run();
            timer.wait(5);
            switch (test.getCounts()) {
                case [reads, writes]: trace('Cap $lockCap: $reads $writes ${reads+writes}');
            }
            test.kill();
        }
    }

}
