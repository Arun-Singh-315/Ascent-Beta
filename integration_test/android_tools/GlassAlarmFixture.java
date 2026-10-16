package com.arun.ascent.qa.glass;
import android.app.*;
import android.content.*;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import java.lang.reflect.Method;
public class GlassAlarmFixture extends Instrumentation {
 Bundle args;
 public void onCreate(Bundle b) {super.onCreate(b);args=b;start();}
 public void onStart() {
  Bundle result=new Bundle();
  try {
   Context c=getTargetContext();
   if(!c.getPackageName().equals("com.arun.ascent.debug") || (c.getApplicationInfo().flags&ApplicationInfo.FLAG_DEBUGGABLE)==0) throw new SecurityException("QA package only");
   Class<?> cls=Class.forName("com.arun.ascent.AlarmStore"); Object store=cls.getField("INSTANCE").get(null);
   String mode=args.getString("mode","create");
   if(mode.equals("create")) {
    c.getSharedPreferences("FlutterSharedPreferences",0).edit().putString("flutter.ascent_theme_mode",args.getString("theme","light")).commit();
    Method m=cls.getMethod("schedule",Context.class,int.class,String.class,long.class);
    Object ok=m.invoke(store,c,900321,"Review your interview notes",System.currentTimeMillis()+6000);
    result.putString("scheduled",ok.toString());
   } else {
    result.putString("alarms",c.getSharedPreferences("ascent_native_alarms",0).getAll().toString());
   }
   finish(Activity.RESULT_OK,result);
  }catch(Exception e){result.putString("error",e.toString());finish(Activity.RESULT_CANCELED,result);}
 }
}
