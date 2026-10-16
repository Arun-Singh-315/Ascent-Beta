package com.arun.ascent.qa.snapshot;
import android.app.Instrumentation;
import android.app.Activity;
import android.app.UiAutomation;
import android.os.Bundle;
import android.graphics.Rect;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.view.accessibility.AccessibilityNodeInfo;
import android.util.Xml;
import org.xmlpull.v1.XmlSerializer;
import java.io.FileOutputStream;
public class Snapshot extends Instrumentation {
  @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
  void node(XmlSerializer xml, AccessibilityNodeInfo n, int depth) throws Exception {
    if(n==null || depth>60)return;
    xml.startTag(null,"node");
    xml.attribute(null,"text",n.getText()==null?"":n.getText().toString());
    xml.attribute(null,"content-desc",n.getContentDescription()==null?"":n.getContentDescription().toString());
    xml.attribute(null,"resource-id",n.getViewIdResourceName()==null?"":n.getViewIdResourceName());
    xml.attribute(null,"package",n.getPackageName()==null?"":n.getPackageName().toString());
    xml.attribute(null,"clickable",Boolean.toString(n.isClickable()));
    xml.attribute(null,"visible",Boolean.toString(n.isVisibleToUser()));
    Rect rect=new Rect();n.getBoundsInScreen(rect);xml.attribute(null,"bounds",rect.toShortString());
    for(int i=0;i<n.getChildCount();i++)node(xml,n.getChild(i),depth+1);
    xml.endTag(null,"node");
  }
  @Override public void onStart() {
    Bundle result=new Bundle();
    try {
      UiAutomation a=getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
      AccessibilityServiceInfo info=a.getServiceInfo();info.flags|=AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS|AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;a.setServiceInfo(info);
      AccessibilityNodeInfo root=null;
      for(int i=0;i<5&&root==null;i++){root=a.getRootInActiveWindow();if(root==null)Thread.sleep(150);}
      if(root==null)throw new IllegalStateException("No active window");
      FileOutputStream out=new FileOutputStream(new java.io.File(getTargetContext().getFilesDir(),"snapshot.xml"));
      XmlSerializer xml=Xml.newSerializer();xml.setOutput(out,"UTF-8");xml.startDocument("UTF-8",true);xml.startTag(null,"hierarchy");
      java.util.List<android.view.accessibility.AccessibilityWindowInfo> windows=a.getWindows();
      if(windows.isEmpty())node(xml,root,0);else for(android.view.accessibility.AccessibilityWindowInfo w:windows)node(xml,w.getRoot(),0);
      xml.endTag(null,"hierarchy");xml.endDocument();out.close();result.putString("snapshot","ready");
      finish(Activity.RESULT_OK,result);
    } catch(Exception e){result.putString("snapshotError",e.toString());finish(Activity.RESULT_CANCELED,result);}
  }
}
