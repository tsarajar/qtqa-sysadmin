class ci_tester::base {
    # ci_tester setup common to all operating systems
    class { 'baselayout': testuser => $ci_tester::testuser }
    include puppet
    include sshkeys
    include qt_prereqs
}
