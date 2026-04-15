#!/usr/bin/perl --
#
# HENNGE ONE ACCESS LOG DOWNLOAD SCRIPT WITH CSV STREAM API
#
# v2.0.0 2026-04-15

# HENNGE ONE API Reference
#
# for HENNGE ONE Access Log
# https://developers.hennge.com/docs/hac-api/45c1c10d89ff4-streams-access-logs-as-a-csv

# for HENNGE ONE Admin Log
# https://developers.hennge.com/docs/hac-api/03929e99664d9-streams-admin-logs-as-a-csv

# for HENNGE ONE User Operation Log
# https://developers.hennge.com/docs/hac-api/82d7a610b7cb2-streams-user-logs-as-a-csv 

# It requires perl JSON module to decode JSON data
# Ubuntu Linux
# sudo apt install libjson-perl
use JSON;

# It requires perl DateTime and ISO8601 module
# Ubuntu Linux
# sudo apt install libdatetime-perl
# sudo apt install libdatetime-format-iso8601-perl
use DateTime;
use DateTime::Format::ISO8601;

# ===========================================
# SCRIPT Configuration
# ===========================================
# Debug mode (0:OFF,1:ON)
$DEBUG = 1;

# Log download settings
$DOWNLOAD_HENNGE_LOG = 1;
$DOWNLOAD_HENNGE_ADMIN_LOG = 1;
$DOWNLOAD_HENNGE_USER_LOG = 1;
$DOWNLOAD_HENNGE_SECURE_TRANSFER_LOG = 1;

# period of running this script in seconds
$PERIOD = 600;

# HENNGE ONE API TOKEN expires in 3600 seconds, if Token is older than $AGE_THRESHOULD, renew API TOKEN
$AGE_THRESHOULD = 3300;

# Timezone is based on UTC
$NOW = DateTime->now();

# FILE and Directory Configuration
$BASE_DIR = '/root/hennge/';
$LOG_DIR = '/var/log/hennge/';
$LOG_DIR_ADMIN = '/var/log/hennge/admin/';
$LOG_DIR_USER = '/var/log/hennge/user/';
$LOG_DIR_SecureTransfer = '/var/log/hennge/securetransfer/';

# TOKEN File without CRLF
$TOKEN_FILE = '.HenngeAPIBearerToken';

# UTC format text that to collect log time 2025-01-01T00:00:00 without CRLF
# It is updated with $PERIOD seconds after downloading log
$TIMESTAMP_FILE = '.TimeStampFile';

# HENNGE ONE API URLs Definition
$TOKEN_URL = 'https://ap.ssso.hdems.com/oauth/token';
$API_BASE_URL = 'https://api.auth.hennge.com/20241126/logs/access/';
$API_BASE_URL_ADMIN = 'https://api.auth.hennge.com/20241126/logs/admin/';
$API_BASE_URL_USER = 'https://api.auth.hennge.com/20241126/logs/user/';
$API_BASE_URL_SecureTransfer = 'https://api.transfer.hennge.com/v1/logs/transfers';

# IN THE PRODUCTION, BE CAREFUL FOR RAW SECRET (SECURE CODING REASON)
# IT IS BETTER TO OBTAIN THESE INFORMATION FROM ENVIRONMENT VARIABLES or SOME OTHER FILES.
$CLIENT_ID = '';
$CLIENT_SECRET = '';

# API Key for Secure Transfer
$API_KEY = '';

# TOKEN CHECK
$TOKEN_GENERATE = 0;
if (-e $BASE_DIR.$TOKEN_FILE){
  if ($DEBUG>0 ) {
    print "TOKEN File ".$BASE_DIR.$TOKEN_FILE." exist.\n";
  }
# TOKEN FILE SIZE CHECK
  if ( (stat $BASE_DIR.$TOKEN_FILE)[7] == 0 ){
    if ($DEBUG>0 ) {
      print "TOKEN File ".$BASE_DIR.$TOKEN_FILE." file size is 0.\n";
    }
    $TOKEN_GENERATE = 1;
  }else{
    $TOKEN_AGE = time - (stat $BASE_DIR.$TOKEN_FILE)[9];
      if ($DEBUG>0 ) {
        print "TOKEN File AGE is ".$TOKEN_AGE." seconds.\n";
      }
      if ( $TOKEN_AGE > $AGE_THRESHOULD ) {
        $TOKEN_GENERATE = 1;
      }
  }
}else{
  if ($DEBUG>0 ) {
    print "TOKEN File ".$BASE_DIR.$TOKEN_FILE." does not exist.\n";
  }
  $TOKEN_GENERATE = 1;
}

# TOKEN GENERATION/READ PROCESS
if ( $TOKEN_GENERATE == 1 ){
  $CREDENTIAL_BASE64 = `echo -n $CLIENT_ID:$CLIENT_SECRET | base64 -w 0`;
  $TOKEN_JSON_Command = "curl -L --request POST --url $TOKEN_URL --header 'content-type: application/x-www-form-urlencoded' --header 'authorization: Basic $CREDENTIAL_BASE64' --data grant_type=client_credentials";
  $TOKEN_JSON = decode_json(`$TOKEN_JSON_Command`);
  $TOKEN = $TOKEN_JSON->{'access_token'};
  if ($DEBUG>0 ) {
    print "New Token\n".$TOKEN."\nis generated.\n";;
  }
  # WRITE TOKEN FILE
  $R = `echo -n $TOKEN > $BASE_DIR$TOKEN_FILE`;
}else{
  $TOKEN = `cat $BASE_DIR$TOKEN_FILE`;
  if ($DEBUG>0 ) {
    print "Existing Token ".$TOKEN." is reused.\n";;
  }
}

# DECIDE THE PERIOD FOR OBTAIN LOGS
if (-e $BASE_DIR.$TIMESTAMP_FILE){
  if ($DEBUG>0 ) {
    print "TimeStamp File ".$BASE_DIR.$TIMESTAMP_FILE." exist.\n";
  }
  $FromTime = DateTime::Format::ISO8601->parse_datetime(`cat $BASE_DIR$TIMESTAMP_FILE`);
  $FromTimeEpoch = $FromTime->epoch;
  $NOWEpoch = $NOW->epoch;
  $DIFF = $NOWEpoch - $FromTimeEpoch;
  if ($DEBUG>0) {
    print "TimeStamp File: ".$FromTime."\n";
    print "Now datetime: ".$NOW."\n";
    print "File Timestamp: ".$FromTimeEpoch."\nNow Timestamp: ".$NOWEpoch."\ndiff=".$DIFF."\n";
  }
  # Script is called in less than $PERIOD seconds
  if ( $DIFF < 0 ){
    if ($DEBUG>0) {
      print "Timesramp file indicates future time. Please confirm it and write in UTC timezone.\n";
    }
    exit;
  }
  if ( $DIFF < $PERIOD ){
    if ($DEBUG>0) {
      print "This script is called less than ".$PERIOD." seconds and exit.\n";
    }
    exit;
  }else{
  # Decide the log period and next timestamp
    $NextTimeEpoch = $FromTimeEpoch + $PERIOD;
    $ToTimeEpoch = $FromTimeEpoch + $PERIOD -1;

    $NextTime = DateTime->from_epoch(epoch => $NextTimeEpoch);
    $ToTime = DateTime->from_epoch(epoch => $ToTimeEpoch);    
    if ($DEBUG>0) {
      print "Log will be downloaded from ".$FromTime." to ".$ToTime." and Next time start with ".$NextTime."\n";
    }

    # GET ACCESS LOG
    if ($DOWNLOAD_HENNGE_LOG > 0) {

      $StreamAccessLogCmd = "curl --request GET --url ".$API_BASE_URL.$FromTime."Z/".$ToTime."Z/download/csv/ --header 'Accept: application/json' --header 'Authorization: Bearer ".$TOKEN."'";

      if ($DEBUG>0) {
        print "Command:\n".$StreamAccessLogCmd;
      }
      $CSV = `$StreamAccessLogCmd`;
      if ( $CSV =~ /Timestamp\,Username/){
        $LogFileName = "access_".$FromTimeEpoch.".csv";
        if ($DEBUG>0) {
          print "HENNGE LOG is successfully downloaded to ".$LOG_DIR.$LogFileName."\n";
        }
        open(FH,">> $LOG_DIR/$LogFileName");
        print FH $CSV;
        close(FH);
        $R = `logger $FromTime - $ToTime HENNGE ONE Access Log is downloaded to $LOG_DIR$LogFileName`;
      }else{
        print "ERROR!\n";
        print $CSV;
      }
    }
   
    # GET ADMIN LOG
    if ($DOWNLOAD_HENNGE_ADMIN_LOG > 0) {

      $StreamAdminLogCmd = "curl --request GET --url ".$API_BASE_URL_ADMIN.$FromTime."Z/".$ToTime."Z/download/csv/ --header 'Accept: application/json' --header 'Authorization: Bearer ".$TOKEN."'";

      if ($DEBUG>0) {
        print "Command:\n".$StreamAdminLogCmd;
      }
      $CSV = `$StreamAdminLogCmd`;
      if ( $CSV =~ /Timestamp\,Actor/){
        $LogFileName = "admin_".$FromTimeEpoch.".csv";
        if ($DEBUG>0) {
          print "HENNGE ONE ADMIN LOG is successfully downloaded to $LOG_DIR_ADMIN$LogFileName\n";
        }
        open(FH,">> $LOG_DIR_ADMIN$LogFileName");
        print FH $CSV;
        close(FH);
        $R = `logger $FromTime - $ToTime HENNGE ONE Admin Log is downloaded to $LOG_DIR_ADMIN$LogFileName`;
      }else{
        print "ERROR!\n";
        print $CSV;
      }
    }

    # GET USER OPERATION LOG
    if ($DOWNLOAD_HENNGE_USER_LOG > 0) {

      $UserOperationLogCmd = "curl --request GET --url ".$API_BASE_URL_USER.$FromTime."Z/".$ToTime."Z/download/csv/ --header 'Accept: application/json' --header 'Authorization: Bearer ".$TOKEN."'";

      if ($DEBUG>0) {
        print "Command:\n".$UserOperationLogCmd."\n";
      }
      $CSV = `$UserOperationLogCmd`;
      if ( $CSV =~ /Timestamp\,Actor/){
        $LogFileName = "user_".$FromTimeEpoch.".csv";
        if ($DEBUG>0) {
          print "HENNGE ONE USER LOG is sucessfully downloaded to $LOG_DIR_USER$LogFileName\n";
        }
        open(FH,">> $LOG_DIR_USER$LogFileName");
          print FH $CSV;
        close(FH);
        $R = `logger $FromTime - $ToTime HENNGE ONE User Operation Log is downloaded to $LOG_DIR_USER$LogFileName`;
      }else{
        print "ERROR!\n";
        print $CSV;
      }
    }
    # GET SecureTransfer LOG
    if ( $DOWNLOAD_HENNGE_SECURE_TRANSFER_LOG > 0) {

      $SecureTransferAccessLogCmd = "curl --request GET --url '".$API_BASE_URL_SecureTransfer."?created_after=".$FromTime."Z&created_before=".$ToTime."Z' --header 'Accept: application/json' --header 'x-api-key: ".$API_KEY."'";

      if ($DEBUG>0) {
        print "Command:\n".$SecureTransferAccessLogCmd."\n";
      }

      $LogFileName = "st_".$FromTimeEpoch.".json";
      $API_DATA_JSON = `$SecureTransferAccessLogCmd`;
      if( $API_DATA_JSON =~ /\{\"next_cursor\":\"\",\"data\":\[\]\}/ ) {
          print "No Access Log Entries.\n";
      }else{
        if ($DEBUG>0) {
          print "API Downloaded data:\n".$API_DATA_JSON."\n";
        }

        $API_DATA = decode_json($API_DATA_JSON);
        $OUTPUT = '';
        foreach my $data (@{$API_DATA->{data}}) {
          $OUTPUT = $OUTPUT.encode_json($data)."\n";
        }
        open(FH,">> $LOG_DIR_SecureTransfer$LogFileName");
        print FH $OUTPUT;
        close(FH);

        if ($DEBUG>0) {
          print "$FromTime - $ToTime HENNGE Secure Transfer Access Log is downloaded to $LOG_DIR_SecureTransfer$LogFileName\n";
        }

        $R = `logger $FromTime - $ToTime HENNGE Secure Transfer Access Log is downloaded to $LOG_DIR_SecureTransfer$LogFileName`;
      }
    }    

    # Write next time stamp file
    $R = `echo -n $NextTime > $BASE_DIR$TIMESTAMP_FILE`;
  }

} else {

  if ($DEBUG>0 ) {
    print "TimeStamp File ".$BASE_DIR.$TIMESTAMP_FILE." is not exist.\n";
  }

}
