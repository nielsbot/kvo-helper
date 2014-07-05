kvo-helper
==========

A helper to make KVO observing easier. You can use a block as your observer, and it automatically deregisters itself when the observed object is being deallocated. (I think tracking all KVO observers so you can unregister them is a major weakness of the KVO API)

Let me know if you find bugs. Please credit me if you use this.
