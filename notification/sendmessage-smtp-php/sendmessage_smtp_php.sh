#!/usr/bin/php
<?php
/*
** This program is sendmail script with ISO-2022-JP for ZABBIX.
**
** Auther: Takanori Suzuki
** 
** Copyright (C) 2005-2011 ZABBIX-JP 
** This program is licenced under the GPL
**/

require 'vendor/autoload.php';
use Michelf\MarkdownExtra;

/* setting */
$MAIL_FROM      = "zabbix@company.com";
$MAIL_FROMNAME  = "Zabbix 通知";
$MAIL_SMTP_HOST = 'smtp.example.com';
$MAIL_SMTP_PORT = 25;
$MAIL_SMTP_SEC  = "ssl";
$MAIL_SMTP_USER = 'XXXXXXXX';
$MAIL_SMTP_PASS = 'XXXXXXXX';
$DATAPATH = '/var/zabbix/';


/* setting */

$MAIL_TO      = $argv[1];

/*
 * サブジェクトフォーマット
 * 送信したいサブジェクト ###{EVENT.ID}  {TRIGGER.NSEVERITY}
 */

// サブジェクト解体
preg_match('/(.*)###(\d*)\s*(\d*)/', $argv[2], $m);
$MAIL_SUBJECT = $m[1];
$id = $m[2];

// 優先度設定
$PRIORITY = 3;
switch ($m[3]) {
    case "0":
        // 分類無し
        $PRIORITY = 3;
        break;
    case "1":
        // 情報
        $PRIORITY = 3;
        break;
    case "2":
        // 警告
        $PRIORITY = 3;
        break;
    case "3":
        // 障害
        $PRIORITY = 1;
        break;
    case "4":
        // 重度障害
        $PRIORITY = 1;
        break;
    case "5":
        // 致命的な障害
        $PRIORITY = 1;
        break;
}

// HTMLメール対応
$MAIL_MESSAGE = <<<EOD
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" />
<html xmlns="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Language" content="ja" />
    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
    <meta name="viewport" content="initial-scale=1.0,width=device-width" />
    <title>$MAIL_SUBJECT</title>
    <style type="text/css">
h1,h2 {
  font-size: 110%
}
blockquote {
  margin-left: 0.5em;
  padding-left: 0.5em;
  border-left: 1px solid #CCCCCC;
}
body {
  font-size: 90%;
}
pre{
  font-size: 90%
  display: block;
  padding: 0.5em;
  width: 70%;
  background-color: #DDDDDD;
  border: 1px dotted #666666;
}
code{
font-size: 90%
}
  </style>
  </head>
EOD;

// Markdownフォーマットの展開
$MAIL_MESSAGE .= "<body>" . MarkdownExtra::defaultTransform($argv[3]) . "</body>";
$MAIL_MESSAGE .= "</html>";


function GUID()
{
    if (function_exists('com_create_guid') === true)
    {
        return trim(com_create_guid(), '{}');
    }
 
    return sprintf('%04X%04X-%04X-%04X-%04X-%04X%04X%04X', mt_rand(0, 65535), mt_rand(0, 65535), mt_rand(0, 65535), mt_rand(16384, 20479), mt_rand(32768, 49151), mt_rand(0, 65535), mt_rand(0, 65535), mt_rand(0, 65535));
}

function getNewThreadIndex()
{
    // Outlook独自ヘッダー Thread-Index 生成
    $offset = ((new DateTime())->getTimeStamp() - (new DateTime("1601-01-01T00:00:00.000Z"))->getTimeStamp());
    $hex = hex2bin(substr(sprintf("%016X",$offset *10 *1000 *1000), 0, 12) . str_replace ('-', '', GUID()));
    return base64_encode($hex);
}
function getNextThreadIndex($parent)
{
    // Outlook独自ヘッダー Thread-Index リプライ生成
    $parenthex = bin2hex(base64_decode($parent));
    
    $parentdate = new DateTime("1601-01-01T00:00:00.000Z");
    $parentdate->modify("+". sprintf("%d",hexdec(substr($parenthex, 0, 12) ."0000")/10 /1000/1000). " seconds" );
    
    $c_time_offset  = ((new DateTime())->getTimeStamp() - $parentdate->getTimeStamp()) *10 *1000 *1000;
    $time_diff  = sprintf("%064s",decbin($c_time_offset)) ."\n";
    $binary = substr($time_diff, 15, 31);
    return base64_encode(hex2bin($parenthex . sprintf("%010X", intval(sprintf("%040s", $binary),2))));
}

$mailer = new PHPMailer();
//$mailer->SMTPDebug = 2;
$mailer->IsSMTP();

$mailer->Host = $MAIL_SMTP_HOST;
$mailer->Port = $MAIL_SMTP_PORT;
$mailer->SMTPSecure = $MAIL_SMTP_SEC;

$mailer->Priority = $PRIORITY;
$mailer->SMTPAuth = true;
$mailer->Username = $MAIL_SMTP_USER;
$mailer->Password = $MAIL_SMTP_PASS;

$mailer->From     = $MAIL_FROM;
$mailer->AddAddress($MAIL_TO);

$mailer->CharSet = "UTF-8";
$mailer->Encoding = "base64";
$mailer->FromName = $MAIL_FROMNAME;
$mailer->Subject  = $MAIL_SUBJECT;
$mailer->Body     = $MAIL_MESSAGE;

$mailer->IsHTML(true);
// Zabbixフラグ
//$mailer->addCustomHeader('X-Message-Flag', 'Zabbix');

if ( file_exists("$DATAPATH/$MAIL_TO.$id")) {
    // 管理ファイル読み込み
    $rndf = fopen ("$DATAPATH/$MAIL_TO.$id", "r");
    $rnd = chop( fgets($rndf) );
    $thr = rtrim(fgets($rndf));
    $thi = rtrim(fgets($rndf));
    fclose($rndf);

    $mailer->addCustomHeader('In-Reply-To', '<APPLI.' . $id . '.' . $rnd . '@' . gethostname() . '>');
    $mailer->addCustomHeader('References', '<APPLI.' . $id . '.' . $rnd . '@' . gethostname() . '>');
    $mailer->addCustomHeader('Thread-Topic', $thr);
    $mailer->addCustomHeader('Thread-Index', getNextThreadIndex($thi)); // Thread-Indexリプライ設定
}else{
    $rnd = rand (10000000,99999999);
    $mailer->MessageID = '<APPLI.' . $id . '.' . $rnd . '@' . gethostname() . '>';
    $thr = rtrim($MAIL_SUBJECT);
    $thi = getNewThreadIndex();

    // 初期ヘッダ作成
    $mailer->addCustomHeader('Thread-Topic', $thr);
    $mailer->addCustomHeader('Thread-Index', $thi);

    // 管理ファイル作成
    $idf = fopen("$DATAPATH/$MAIL_TO.$id","w");
    fwrite($idf, $rnd . "\n");
    fwrite($idf, $thr . "\n");
    fwrite($idf, $thi);
    fclose($idf);
}

if(!$mailer->Send()){
   print "failed: " . $mailer->ErrorInfo . "\n";
}else{
   print "success" . "\n";
   //print $mailer->GetSentMIMEMessage() . "\n";
}
?>
