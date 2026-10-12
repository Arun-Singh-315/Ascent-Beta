package com.arun.ascent.qa.snapshot;
import android.app.Instrumentation;
import android.app.Activity;
import android.content.Context;
import android.content.ContentValues;
import android.content.pm.ApplicationInfo;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import java.io.File;
import java.lang.reflect.Method;

/** QA-only instrumentation: refuses production and never creates a profile. */
public class AlarmFixture extends Instrumentation {
  Bundle arguments;
  @Override public void onCreate(Bundle args) { super.onCreate(args); arguments=args; start(); }
  File find(File dir,int depth) {
    if(depth>5)return null;
    File[] files=dir.listFiles();if(files==null)return null;
    for(File f:files){ if(f.isFile()&&f.getName().equals("ascent_db.sqlite"))return f; if(f.isDirectory()){File hit=find(f,depth+1);if(hit!=null)return hit;} }
    return null;
  }
  @Override public void onStart() {
    Bundle result=new Bundle();
    try {
      Context c=getTargetContext();
      if(!c.getPackageName().equals("com.arun.ascent.debug")||(c.getApplicationInfo().flags&ApplicationInfo.FLAG_DEBUGGABLE)==0)throw new SecurityException("Requires isolated Ascent debug package");
      File file=find(c.getDataDir(),0);if(file==null)throw new IllegalStateException("Launch QA app once to create its database");
      SQLiteDatabase db=SQLiteDatabase.openDatabase(file.getAbsolutePath(),null,SQLiteDatabase.OPEN_READWRITE);
      String mode=arguments.getString("mode","create");
      long id=Long.parseLong(arguments.getString("id","0"));
      if(mode.equals("inspect")) {
        Cursor cursor=db.rawQuery("SELECT scheduled_at,is_active,alarm_enabled FROM reminders WHERE id=?",new String[]{Long.toString(id)});
        if(!cursor.moveToFirst())throw new IllegalStateException("Fixture reminder missing");
        result.putString("scheduledAt",Long.toString(cursor.getLong(0)));result.putString("active",Integer.toString(cursor.getInt(1)));result.putString("alarmMode",Integer.toString(cursor.getInt(2)));cursor.close();
        result.putString("nativeEvents",c.getSharedPreferences("ascent_native_alarms",Context.MODE_PRIVATE).getString("events","[]"));
      } else {
        long at=System.currentTimeMillis()+15000;
        ContentValues values=new ContentValues();values.put("scheduled_at",at/1000);values.put("is_active",1);values.put("alarm_enabled",1);
        String title=mode.equals("create")?"QA alarm: call the accountant":"QA alarm: Done stops ringing";
        values.put("title",title);
        if(id==0){values.put("created_at",System.currentTimeMillis()/1000);id=db.insertOrThrow("reminders",null,values);}else db.update("reminders",values,"id=?",new String[]{Long.toString(id)});
        Class<?> storeClass=Class.forName("com.arun.ascent.AlarmStore");Object store=storeClass.getField("INSTANCE").get(null);
        Method schedule=storeClass.getMethod("schedule",Context.class,int.class,String.class,long.class);
        Object ok=schedule.invoke(store,c,(int)id,title,at);
        if(!Boolean.TRUE.equals(ok))throw new IllegalStateException("Native scheduling refused; check QA notification/exact access");
        result.putString("id",Long.toString(id));result.putString("scheduledAt",Long.toString(at));result.putString("scheduled","true");
      }
      db.close();finish(Activity.RESULT_OK,result);
    }catch(Exception e){result.putString("fixtureError",e.toString());finish(Activity.RESULT_CANCELED,result);}
  }
}
