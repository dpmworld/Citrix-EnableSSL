<H1>Easy way to bind SSL certificate to Citrix Broer Service</H1>

Unless you have IIS installed Citrix Delivery Controllers do not have a GUI to manage SSL certificates and bound them to the Citrix Broer Service.
Citrix provide a couple of KB articole on how to <A HREF="https://support.citrix.com/s/article/CTX218986-secure-xml-traffic-between-storefront-and-delivery-controller?language=en_US">Secure XML traffic between StoreFront and Delivery Controller</A>.

The script checks for existing binding and let you choose the certificate to bind to Citrix Broker Service.<BR>
It does not bind the certificate, but will output all the commands to properly unbind/bind the certificate to the service using netsh.