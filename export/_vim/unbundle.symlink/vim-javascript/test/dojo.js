/*jshint unused:false*/
/*global dojo*/

(function(global, dojo) {

    require(["dojo/dom"], function(dom) {
        dom.byId().
        dom.isDescendant();
        dom.setSelectable();
    });

    require(["dojo/dom-attr"], function(domAttr) {
        domAttr.has();
        domAttr.get();
        domAttr.set();
        domAttr.remove();
        domAttr.getNodeProp();
    });

    require(["dojo/dom-class"], function(domClass) {
        domClass.contains();
        domClass.add();
        domClass.remove();
        domClass.replace();
        domClass.toggle();
    });
}(this, dojo));
