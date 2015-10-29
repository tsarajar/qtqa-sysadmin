class network_test_server::linux::frox {

    if ($::operatingsystem == "Ubuntu") and ($lsbmajdistrelease >= 12) {
        source_install { "frox" :
            creates => "/usr/local/sbin/frox",
            url => "http://frox.sourceforge.net/download/frox-0.7.18.tar.gz",
            configureparams => "--enable-configfile=/etc/frox.conf",
        }
    
        service {
            "frox":
                enable  =>  true,
                ensure  =>  running,
                require =>  [ Source_Install["frox"], File["/etc/default/frox", "/etc/frox.conf" ] ],
            ;
        }
    
        file {
            "/etc/default/frox":
                source  =>  "puppet:///modules/network_test_server/config/frox/etc_default_frox",
                require =>  Source_Install["frox"],
                notify  =>  Service["frox"],
            ;
            "/etc/frox.conf":
                source  =>  "puppet:///modules/network_test_server/config/frox/frox.conf",
                require =>  Source_Install["frox"],
                notify  =>  Service["frox"],
            ;
            "/etc/init.d/frox":
                source  =>  "puppet:///modules/network_test_server/init/frox",
                require =>  Source_Install["frox"],
                notify  =>  Service["frox"],
            ;
        }
    }
    # old implementation that was used in Ubuntu 10.04
    else {
    
        package {
            "frox":     ensure  =>  present;
        }
    
        service {
            "frox":
                enable  =>  true,
                ensure  =>  running,
                require =>  [ Package["frox"], File["/etc/default/frox", "/etc/frox.conf" ] ],
            ;
        }
    
        file {
            "/etc/default/frox":
                source  =>  "puppet:///modules/network_test_server/config/frox/etc_default_frox",
                require =>  Package["frox"],
                notify  =>  Service["frox"],
            ;
            "/etc/frox.conf":
                source  =>  "puppet:///modules/network_test_server/config/frox/frox.conf",
                require =>  Package["frox"],
                notify  =>  Service["frox"],
            ;
        }
    }
}

