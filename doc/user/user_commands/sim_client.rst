.. _sim_client(1):

sim_client
==========

SYNOPSIS
--------

**sim_client**
[ **-p** *port* ]
[ **-m** *message* ]
[ **-h** *hostname* ]
[ **-s** *service* ]


DESCRIPTION
-----------

sim_client is a sample application, primarily useful for testing
purposes.  It contacts its server :ref:`sim_server(8)`, authenticates
to it using Kerberos version 5 tickets, and sends the server signed
and encrypted copies of the specified message.


SEE ALSO
--------

:ref:`kinit(1)`, :ref:`sim_server(8)`
