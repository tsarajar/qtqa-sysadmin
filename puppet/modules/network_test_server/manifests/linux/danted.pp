class network_test_server::linux::danted {


    if ($::operatingsystem == "Ubuntu") and ($lsbmajdistrelease >= 12) {
        source_install { "danted" :
            creates => "/usr/sbin/socksd",
            url => "http://www.inet.no/dante/files/dante-1.2.0.tar.gz",
            configureparams => "",
        }


        service {
            "danted":
                enable  =>  true,
                ensure  =>  running,
                require =>  Source_Install["danted"],
            ;
            "danted-authenticating":
                enable  =>  true,
                ensure  =>  running,
                require =>  Source_Install["danted"],
            ;
        }

        file {
            "/etc/danted.conf":
                source  =>  "puppet:///modules/network_test_server/config/danted/danted.conf",
                require =>  Source_Install["danted"],
                notify  =>  Service["danted"],
            ;
            "/etc/danted-authenticating.conf":
                source  =>  "puppet:///modules/network_test_server/config/danted/danted-authenticating.conf",
                require =>  Source_Install["danted"],
                notify  =>  Service["danted-authenticating"],
            ;
            "/etc/init.d/danted":
                source  =>  "puppet:///modules/network_test_server/init/sockd",
            ;
            "/etc/init.d/danted-authenticating":
                source  =>  "puppet:///modules/network_test_server/init/sockd-authenticating",
            ;
        }
    } else {
        package { "dante-server":
            ensure  =>  present,
            require =>  File["/etc/init.d/danted", "/etc/init.d/danted-authenticating"],
        }

        service {
            "danted":
                enable  =>  true,
                ensure  =>  running,
                require =>  Package["dante-server"],
            ;
            "danted-authenticating":
                enable  =>  true,
                ensure  =>  running,
                require =>  Package["dante-server"],
            ;
        }

        file {
            "/etc/danted.conf":
                source  =>  "puppet:///modules/network_test_server/config/danted/danted.conf",
                require =>  Package["dante-server"],
                notify  =>  Service["danted"],
            ;
            "/etc/danted-authenticating.conf":
                source  =>  "puppet:///modules/network_test_server/config/danted/danted-authenticating.conf",
                require =>  Package["dante-server"],
                notify  =>  Service["danted-authenticating"],
            ;
            "/etc/init.d/danted":
                source  =>  "puppet:///modules/network_test_server/init/danted",
            ;
            "/etc/init.d/danted-authenticating":
                source  =>  "puppet:///modules/network_test_server/init/danted-authenticating",
            ;
        }
    }
    if ($::operatingsystem == "Ubuntu") and ($lsbmajdistrelease >= 12) {
        file {
            "/lib/x86_64-linux-gnu/libc.so":
                ensure =>   'link',
                target =>   "/lib/x86_64-linux-gnu/libc.so.6",
            ;
        }
    }

}

