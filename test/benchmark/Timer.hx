#if neko
import neko.vm.Lock;
#elseif cpp
import cpp.vm.Lock;
#end

@:publicFields
class Timer {

    var aux = new Lock();

    // t in ms
    function wait(?t : Null<Float>) {
        aux.wait(t);
    }

}
