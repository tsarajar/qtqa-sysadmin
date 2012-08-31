# Qt Project CI node for compiling, running autotests
#
class ci_tester(
    # user account used for all testing
    $testuser = $ci_tester::params::testuser,

    # IP address of qt-test-server network test server
    $network_test_server_ip = $ci_tester::params::network_test_server_ip,

    # Use a Pulse agent?
    $pulseagent_enabled = $ci_tester::params::pulseagent_enabled,

    # Use a custom, shorter Pulse agent work dir?
    $pulseagent_short_datadir = $ci_tester::params::pulseagent_short_datadir,

    # Jenkins parameters
    $jenkins_enabled = $ci_tester::params::jenkins_enabled,
    $jenkins_server = $ci_tester::params::jenkins_server,
    $jenkins_slave_name = $ci_tester::params::jenkins_slave_name,

    # Use icecream distributed compilation tool?
    $icecc_enabled = $ci_tester::params::icecc_enabled,

    # icecream scheduler host; empty means autodiscovery
    $icecc_scheduler_host = $ci_tester::params::icecc_scheduler_host

) inherits ci_tester::params {
    case $::kernel {
        Linux:   { include ci_tester::linux }
        Darwin:  { include ci_tester::mac }
        Windows: { include ci_tester::windows }
        default: { warning("No implementation for ci_tester on $::kernel") }
    }
}