import 'dart:io';

void main() async {
  print('جاري البحث عن أداة التوقيع...');
  
  // محاولة العثور على مسار جافا من خلال أندرويد ستوديو أو النظام
  String keytoolPath = 'keytool'; 
  
  print('بدء عملية توليد ملف المفاتيح (Keystore)...');
  
  var result = await Process.run(keytoolPath, [
    '-genkey', '-v',
    '-keystore', 'android/app/upload-keystore.jks',
    '-storetype', 'JKS',
    '-keyalg', 'RSA',
    '-keysize', '2048',
    '-validity', '10000',
    '-alias', 'upload',
    '-storepass', 'alghaith@2024',
    '-keypass', 'alghaith@2024',
    '-dname', 'CN=Alghaith App, OU=Development, O=Alghaith, L=Baghdad, S=Baghdad, C=IQ'
  ]);

  if (result.exitCode == 0) {
    print('✅ تم إنشاء ملف upload-keystore.jks بنجاح في مجلد android/app');
  } else {
    print('❌ فشل التوليد التلقائي. يرجى التأكد من تنصيب Java JDK.');
    print('خطأ: ${result.stderr}');
  }
}
