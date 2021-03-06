<?php
#############################################################################
##
## Copyright (C) 2013 Digia Plc and/or its subsidiary(-ies).
## Contact: http://www.qt-project.org/legal
##
## This file is part of the Qt Metrics web portal.
##
## $QT_BEGIN_LICENSE:LGPL$
## Commercial License Usage
## Licensees holding valid commercial Qt licenses may use this file in
## accordance with the commercial license agreement provided with the
## Software or, alternatively, in accordance with the terms contained in
## a written agreement between you and Digia.  For licensing terms and
## conditions see http://qt.digia.com/licensing.  For further information
## use the contact form at http://qt.digia.com/contact-us.
##
## GNU Lesser General Public License Usage
## Alternatively, this file may be used under the terms of the GNU Lesser
## General Public License version 2.1 as published by the Free Software
## Foundation and appearing in the file LICENSE.LGPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU Lesser General Public License version 2.1 requirements
## will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
##
## In addition, as a special exception, Digia gives you certain additional
## rights.  These rights are described in the Digia Qt LGPL Exception
## version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
##
## GNU General Public License Usage
## Alternatively, this file may be used under the terms of the GNU
## General Public License version 3.0 as published by the Free Software
## Foundation and appearing in the file LICENSE.GPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU General Public License version 3.0 requirements will be
## met: http://www.gnu.org/copyleft/gpl.html.
##
##
## $QT_END_LICENSE$
##
#############################################################################
?>

<?php

// (Note: session started in getfilters.php)

/* Get list of Project values to session variable xxx (if not done already) */
if(!isset($_SESSION['arrayProjectName'])) {

    /* Connect to the server */
    require(__DIR__.'/../connect.php');

    /* Select database */
    if ($useMysqli) {
        // Selected in mysqli_connect() call
    } else {
        $selectdb="USE $db";
        $result = mysql_query($selectdb) or die ("Failure: Unable to use the database !");
    }

    /* Step 1: Read name, latest Build number and calculate the Autotest result counting min/max scope for each Project */
    $sql = "SELECT project, build_number, result, timestamp, duration
            FROM ci_latest
            ORDER BY project;";
    $dbColumnCiProject = 0;
    $dbColumnCiBuildNumber = 1;
    $dbColumnCiResult = 2;
    $dbColumnCiTimestamp = 3;
    $dbColumnCiDuration = 4;
    if ($useMysqli) {
        $result = mysqli_query($conn, $sql);
        $numberOfRows = mysqli_num_rows($result);
    } else {
        $result = mysql_query($sql) or die (mysql_error());
        $numberOfRows = mysql_num_rows($result);
    }
    $arrayProjectName = array();                                                     // Full Project name (e.g. "QtDeclarative_dev_Integration")
    $arrayProjectBuildLatest = array();
    $arrayProjectBuildLatestResult = array();
    $arrayProjectBuildLatestTimestamp = array();
    $arrayProjectBuildLatestDuration = array();
    $arrayProjectBuildScopeMin = array();
    $arrayCiProject = array();                                                       // Plain Project name (e.g. "QtDeclarative")
    $arrayCiBranch = array();                                                        // Plain Branch name (e.g. "dev")
    $numberOfProjects = $numberOfRows;
    for ($j=0; $j<$numberOfProjects; $j++) {                                         // Loop the Projects
        if ($useMysqli)
            $resultRow = mysqli_fetch_row($result);
        else
            $resultRow = mysql_fetch_row($result);
        $arrayProjectName[] = $resultRow[$dbColumnCiProject];                        // Project name
        $arrayProjectBuildLatest[] = $resultRow[$dbColumnCiBuildNumber];             // Latest Build number for the Project
        $arrayProjectBuildLatestResult[] = $resultRow[$dbColumnCiResult];
        $arrayProjectBuildLatestTimestamp[] = $resultRow[$dbColumnCiTimestamp];
        $arrayProjectBuildLatestDuration[] = $resultRow[$dbColumnCiDuration];
        if ($resultRow[$dbColumnCiBuildNumber] - AUTOTEST_LATESTBUILDCOUNT > 0)
            $arrayProjectBuildScopeMin[] = $resultRow[$dbColumnCiBuildNumber] - AUTOTEST_LATESTBUILDCOUNT + 1;   // First Build number in metrics scope
        else
            $arrayProjectBuildScopeMin[] = 1;                                        // Less builds than the scope count
        $arrayCiProject[] = getProjectName($resultRow[$dbColumnCiProject]);          // Read the plain Project name
        $arrayCiBranch[] = getProjectBranch($resultRow[$dbColumnCiProject]);         // Read the plain Project branch
    }
    $arrayCiProject = array_unique($arrayCiProject);                                 // Remove duplicates
    $arrayCiBranch = array_unique($arrayCiBranch);
    $arrayCiBranch = array_filter($arrayCiBranch);                                   // Remove empty values
    sort($arrayCiProject);
    sort($arrayCiBranch);
    $timeProjectValuesStep1 = microtime(true);

    /* Step 2: Read the number of failed significant and insignificant Autotests in latest Build for each Project from the database */
    $arrayProjectBuildLatestSignificantCount = array();
    $arrayProjectBuildLatestInsignificantCount = array();
    for ($i=0; $i<$numberOfProjects; $i++) {                                        // Initialize
        $arrayProjectBuildLatestSignificantCount[$i] = 0;
        $arrayProjectBuildLatestInsignificantCount[$i] = 0;
    }
    $sql = "SELECT project, insignificant
            FROM test_latest";
    $dbColumnTestProject = 0;
    $dbColumnTestInsignificant = 1;
    if ($useMysqli) {
        $result2 = mysqli_query($conn, $sql);
        $numberOfRows2 = mysqli_num_rows($result2);
    } else {
        $result2 = mysql_query($sql) or die (mysql_error());
        $numberOfRows2 = mysql_num_rows($result2);
    }
    for ($j=0; $j<$numberOfRows2; $j++) {                                            // Loop the tests
        if ($useMysqli)
            $resultRow2 = mysqli_fetch_row($result2);
        else
            $resultRow2 = mysql_fetch_row($result2);
        for ($i=0; $i<$numberOfProjects; $i++) {                                     // Loop the Projects (see step 1)
            if ($resultRow2[$dbColumnTestProject] == $arrayProjectName[$i]) {
                if ($resultRow2[$dbColumnTestInsignificant] == 1)
                    $arrayProjectBuildLatestInsignificantCount[$i]++;
                else
                    $arrayProjectBuildLatestSignificantCount[$i]++;
            }
        }
    }
    $timeProjectValuesStep2 = microtime(true);

    /* Step 3: Read the number of Confs (including force success and insignificant) for each Project from the database */
    $arrayProjectBuildLatestConfCount = array();
    $arrayProjectBuildLatestConfCountForceSuccess = array();
    $arrayProjectBuildLatestConfCountInsignificant = array();
    for ($i=0; $i<$numberOfProjects; $i++) {                                        // Initialize
        $arrayProjectBuildLatestConfCount[$i] = 0;
        $arrayProjectBuildLatestConfCountForceSuccess[$i] = 0;
        $arrayProjectBuildLatestConfCountInsignificant[$i] = 0;
    }
    $sql = "SELECT project, forcesuccess, insignificant
            FROM cfg_latest";
    $dbColumnCfgProject = 0;
    $dbColumnCfgForceSuccess = 1;
    $dbColumnCfgInsignificant = 2;
    if ($useMysqli) {
        $result2 = mysqli_query($conn, $sql);
        $numberOfRows2 = mysqli_num_rows($result2);
    } else {
        $result2 = mysql_query($sql) or die (mysql_error());
        $numberOfRows2 = mysql_num_rows($result2);
    }
    for ($j=0; $j<$numberOfRows2; $j++) {                                            // Loop the Confs
        if ($useMysqli)
            $resultRow2 = mysqli_fetch_row($result2);
        else
            $resultRow2 = mysql_fetch_row($result2);
        for ($i=0; $i<$numberOfProjects; $i++) {                                     // Loop the Projects (see step 1)
            if ($resultRow2[$dbColumnCfgProject] == $arrayProjectName[$i]) {
                if ($resultRow2[$dbColumnCfgForceSuccess] == 1)
                    $arrayProjectBuildLatestConfCountForceSuccess[$i]++;
                if ($resultRow2[$dbColumnCfgInsignificant] == 1)
                    $arrayProjectBuildLatestConfCountInsignificant[$i]++;
                $arrayProjectBuildLatestConfCount[$i]++;
            }
        }
    }
    $timeProjectValuesStep3 = microtime(true);

    /* Step 4: Read the number of successful, failed and all Builds for each Project from the database (all must be read separately) */
    $arrayProjectBuildCount = array();                                               // Note: These must not be initialized because not filled by Projects
    $arrayProjectBuildCountSuccess = array();
    $arrayProjectBuildCountFailure = array();
    for ($i=0; $i<$numberOfProjects; $i++) {                                         // Loop the Projects (see step 1)
        $sql = "SELECT 'SUCCESS', COUNT(result) AS 'count'
                FROM ci
                WHERE project=\"$arrayProjectName[$i]\" AND result=\"SUCCESS\"
                UNION
                SELECT 'FAILURE', COUNT(result) AS 'count'
                FROM ci
                WHERE project=\"$arrayProjectName[$i]\" AND result=\"FAILURE\"
                UNION
                SELECT 'Total', COUNT(result) AS 'count'
                FROM ci
                WHERE project=\"$arrayProjectName[$i]\"";                            // Will return three rows
        if ($useMysqli) {
            $result2 = mysqli_query($conn, $sql);
            $numberOfRows2 = mysqli_num_rows($result2);
        } else {
            $result2 = mysql_query($sql) or die (mysql_error());
            $numberOfRows2 = mysql_num_rows($result2);
        }
        for ($j=0; $j<$numberOfRows2; $j++) {                                        // Loop the counts
            if ($useMysqli)
                $resultRow2 = mysqli_fetch_row($result2);
            else
                $resultRow2 = mysql_fetch_row($result2);
            if ($resultRow2[0] == "SUCCESS")
                $arrayProjectBuildCountSuccess[] = $resultRow2[1];
            if ($resultRow2[0] == "FAILURE")
                $arrayProjectBuildCountFailure[] = $resultRow2[1];
            if ($resultRow2[0] == "Total")
                $arrayProjectBuildCount[] = $resultRow2[1];
        }
    }
    $timeProjectValuesStep4 = microtime(true);

    /* Step 5: Read the min and max dates */
    $sql="SELECT MIN(timestamp), MAX(timestamp)
          FROM ci;";
    if ($useMysqli) {
        $result = mysqli_query($conn, $sql);
        $resultRow = mysqli_fetch_row($result);
    } else {
        $result = mysql_query($sql) or die (mysql_error());
        $resultRow = mysql_fetch_row($result);
    }
    $minBuildDate = substr($resultRow[0], 0, 10);
    $maxBuildDate = substr($resultRow[1], 0, 10);
    $timeProjectValuesStep5 = microtime(true);

    /* Step 6: Read the number of all, failed and rerun Autotests (flaky tests) in latest Build for each Project from the database */
    $arrayProjectBuildLatestAutotestCount = array();
    $arrayProjectBuildLatestAutotestFailedCount = array();
    $arrayProjectBuildLatestAutotestRerun = array();
    for ($i=0; $i<$numberOfProjects; $i++) {                                        // Initialize
        $arrayProjectBuildLatestAutotestCount[$i] = 0;
        $arrayProjectBuildLatestAutotestFailedCount[$i] = 0;
        $arrayProjectBuildLatestAutotestRerun[$i] = 0;
    }
    for ($i=0; $i<$numberOfProjects; $i++) {                                        // Loop the Projects (see step 1); Search test results for one Project at a time (to avoid too large return data)
        $projectName = $arrayProjectName[$i];
        $sql = "SELECT passed, failed, skipped, runs
                FROM all_test_latest
                WHERE project=\"$projectName\"";                                    // All tests with details
        $dbColumnTestPassed = 0;
        $dbColumnTestFailed = 1;
        $dbColumnTestSkipped = 2;
        $dbColumnTestRuns = 3;
        if ($useMysqli) {
            $result = mysqli_query($conn, $sql);
            $numberOfRows = mysqli_num_rows($result);
        } else {
            $result = mysql_query($sql) or die (mysql_error());
            $numberOfRows = mysql_num_rows($result);
        }
        for ($j=0; $j<$numberOfRows; $j++) {                                        // Loop the all tests
            if ($useMysqli)
                $resultRow = mysqli_fetch_row($result);
            else
                $resultRow = mysql_fetch_row($result);
            $arrayProjectBuildLatestAutotestCount[$i]++;                            // a) Count the number of Autotests in a Project
            if (checkAutotestFailed($resultRow[$dbColumnTestPassed],
                                    $resultRow[$dbColumnTestFailed],
                                    $resultRow[$dbColumnTestSkipped]))              // b) Count the number of failed Autotests in a Project (identified by case results)
                $arrayProjectBuildLatestAutotestFailedCount[$i]++;
            if ($resultRow[$dbColumnTestRuns] > 1)                                  // c) Count the number of rerun Autotests in a Project (not the number of reruns)
                $arrayProjectBuildLatestAutotestRerun[$i]++;
        }
    }
    $timeProjectValuesStep6 = microtime(true);

    /* Save session variables */
    $_SESSION['arrayProjectName'] = $arrayProjectName;
    $_SESSION['arrayProjectBuildLatest'] = $arrayProjectBuildLatest;
    $_SESSION['arrayProjectBuildLatestResult'] = $arrayProjectBuildLatestResult;
    $_SESSION['arrayProjectBuildLatestTimestamp'] = $arrayProjectBuildLatestTimestamp;
    $_SESSION['arrayProjectBuildLatestDuration'] = $arrayProjectBuildLatestDuration;
    $_SESSION['arrayProjectBuildScopeMin'] = $arrayProjectBuildScopeMin;
    $_SESSION['arrayProjectBuildLatestSignificantCount'] = $arrayProjectBuildLatestSignificantCount;
    $_SESSION['arrayProjectBuildLatestInsignificantCount'] = $arrayProjectBuildLatestInsignificantCount;
    $_SESSION['arrayProjectBuildLatestConfCount'] = $arrayProjectBuildLatestConfCount;
    $_SESSION['arrayProjectBuildLatestConfCountForceSuccess'] = $arrayProjectBuildLatestConfCountForceSuccess;
    $_SESSION['arrayProjectBuildLatestConfCountInsignificant'] = $arrayProjectBuildLatestConfCountInsignificant;
    $_SESSION['arrayProjectBuildLatestAutotestCount'] = $arrayProjectBuildLatestAutotestCount;
    $_SESSION['arrayProjectBuildLatestAutotestFailedCount'] = $arrayProjectBuildLatestAutotestFailedCount;
    $_SESSION['arrayProjectBuildLatestAutotestRerun'] = $arrayProjectBuildLatestAutotestRerun;
    $_SESSION['arrayProjectBuildCount'] = $arrayProjectBuildCount;
    $_SESSION['arrayProjectBuildCountSuccess'] = $arrayProjectBuildCountSuccess;
    $_SESSION['arrayProjectBuildCountFailure'] = $arrayProjectBuildCountFailure;
    $_SESSION['minBuildDate'] = $minBuildDate;
    $_SESSION['maxBuildDate'] = $maxBuildDate;
    $_SESSION['arrayCiProject'] = $arrayCiProject;
    $_SESSION['arrayCiBranch'] = $arrayCiBranch;

    if ($useMysqli) {
        mysqli_free_result($result);                                                 // Free result set
        mysqli_free_result($result2);                                                // Free result set
    }

    /* Close connection to the server */
    require(__DIR__.'/../connectionclose.php');

}

?>