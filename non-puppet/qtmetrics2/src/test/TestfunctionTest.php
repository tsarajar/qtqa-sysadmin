<?php
#############################################################################
##
## Copyright (C) 2015 The Qt Company Ltd.
## Contact: http://www.qt.io/licensing/
##
## This file is part of the Quality Assurance module of the Qt Toolkit.
##
## $QT_BEGIN_LICENSE:LGPL21$
## Commercial License Usage
## Licensees holding valid commercial Qt licenses may use this file in
## accordance with the commercial license agreement provided with the
## Software or, alternatively, in accordance with the terms contained in
## a written agreement between you and The Qt Company. For licensing terms
## and conditions see http://www.qt.io/terms-conditions. For further
## information use the contact form at http://www.qt.io/contact-us.
##
## GNU Lesser General Public License Usage
## Alternatively, this file may be used under the terms of the GNU Lesser
## General Public License version 2.1 or version 3 as published by the Free
## Software Foundation and appearing in the file LICENSE.LGPLv21 and
## LICENSE.LGPLv3 included in the packaging of this file. Please review the
## following information to ensure the GNU Lesser General Public License
## requirements will be met: https://www.gnu.org/licenses/lgpl.html and
## http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
##
## As a special exception, The Qt Company gives you certain additional
## rights. These rights are described in The Qt Company LGPL Exception
## version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
##
## $QT_END_LICENSE$
##
#############################################################################

require_once(__DIR__.'/../Factory.php');

/**
 * Testfunction unit test class
 * @example   To run (in qtmetrics root directory): php <path-to-phpunit>/phpunit.phar ./src/test
 * @since     21-09-2015
 * @author    Juha Sippola
 */

class TestfunctionTest extends PHPUnit_Framework_TestCase
{

    /**
     * Test getName, getShortName, getTestsetName, getTestsetProjectName, getConfName
     * @dataProvider testGetNameData
     */
    public function testGetName($name, $shortName, $testset, $project, $conf)
    {
        $testfunction = new Testfunction($name, $testset, $project, $conf);
        $this->assertEquals($name, $testfunction->getName());
        $this->assertEquals($shortName, $testfunction->getShortName());
        $this->assertEquals($testset, $testfunction->getTestsetName());
        $this->assertEquals($project, $testfunction->getTestsetProjectName());
        $this->assertEquals($conf, $testfunction->getConfName());
    }
    public function testGetNameData()
    {
        return array(
            array(
                'cleanupTestCase',
                'cleanupTestCase',
                'tst_qftp',
                'QtBase',
                'macx-clang_developer-build_OSX_10.8'),
            array(
                'my_testfunction',
                'my_testfunction',
                'my_testset',
                'my_project',
                'my_conf'),
            array(
                'my_long_testfunction_name_that_has_over_50_letters_in_it',
                'my_long_testfunction_name_that_has_over_...s_in_it',
                'my_testset',
                'my_project',
                'my_conf')
        );
    }

    /**
     * Test setResultCounts and getResultCounts
     * @dataProvider testGetResultCountsData
     */
    public function testGetTestsetResultCounts($name, $testset, $project, $conf, $passed, $failed, $skipped)
    {
        $testfunction = new Testfunction($name, $testset, $project, $conf);
        $this->assertTrue($testfunction instanceof Testfunction);
        // Counts not set
        $result = $testfunction->getResultCounts();
        $this->assertArrayHasKey('passed', $result);
        $this->assertArrayHasKey('failed', $result);
        $this->assertArrayHasKey('skipped', $result);
        $this->assertNull($result['passed']);
        $this->assertNull($result['failed']);
        $this->assertNull($result['skipped']);
        // Counts set
        $testfunction->setResultCounts($passed, $failed, $skipped);
        $result = $testfunction->getResultCounts();
        $this->assertArrayHasKey('passed', $result);
        $this->assertArrayHasKey('failed', $result);
        $this->assertArrayHasKey('skipped', $result);
        $this->assertEquals($passed, $result['passed']);
        $this->assertEquals($failed, $result['failed']);
        $this->assertEquals($skipped, $result['skipped']);
    }
    public function testGetResultCountsData()
    {
        return array(
            array('cleanupTestCase', 'tst_qftp', 'QtBase', 'macx-clang_developer-build_OSX_10.8', 1, 2, 3),
            array('cleanupTestCase', 'tst_qftp', 'Qt5', 'macx-clang_developer-build_OSX_10.8', 123456, 654321, 111222),
            array('my_testfunction', 'my_testfunction', 'my_project', 'my_conf', 7, 14, 7)
        );
    }

    /**
     * Test setBlacklistedCounts and getBlacklistedCounts
     * @dataProvider testGetBlacklistedCountsData
     */
    public function testGetBlacklistedCounts($name, $testset, $project, $conf, $bpassed, $btotal)
    {
        $testfunction = new Testfunction($name, $testset, $project, $conf);
        $this->assertTrue($testfunction instanceof Testfunction);
        // Counts not set
        $result = $testfunction->getBlacklistedCounts();
        $this->assertArrayHasKey('bpassed', $result);
        $this->assertArrayHasKey('btotal', $result);
        $this->assertNull($result['bpassed']);
        $this->assertNull($result['btotal']);
        // Counts set
        $testfunction->setBlacklistedCounts($bpassed, $btotal);
        $result = $testfunction->getBlacklistedCounts();
        $this->assertArrayHasKey('bpassed', $result);
        $this->assertArrayHasKey('btotal', $result);
        $this->assertEquals($bpassed, $result['bpassed']);
        $this->assertEquals($btotal, $result['btotal']);
    }
    public function testGetBlacklistedCountsData()
    {
        return array(
            array('cleanupTestCase', 'tst_qftp', 'QtBase', 'macx-clang_developer-build_OSX_10.8', 1, 2),
            array('cleanupTestCase', 'tst_qftp', 'Qt5', 'macx-clang_developer-build_OSX_10.8', 123456, 654321),
            array('my_testfunction', 'my_testfunction', 'my_project', 'my_conf', 7, 14)
        );
    }

}

?>
