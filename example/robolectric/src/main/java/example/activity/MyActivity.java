package example.activity;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;

import android.text.TextUtils;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import java.io.PrintWriter;
import java.io.StringWriter;

public class MyActivity extends Activity  {

  private static final String TAG = "RoboBazelActivity";

  private Button mSendButton;
  private EditText mHostEdit;
  private EditText mPortEdit;
  private EditText mMessageEdit;
  private TextView mResultText;

  @Override
  protected void onCreate(Bundle bundle) {
    super.onCreate(bundle);
    setContentView(R.layout.activity_main);
    mSendButton = (Button) findViewById(R.id.send_button);
    mHostEdit = (EditText) findViewById(R.id.host_edit_text);
    mPortEdit = (EditText) findViewById(R.id.port_edit_text);
    mMessageEdit = (EditText) findViewById(R.id.message_edit_text);
    mResultText = (TextView) findViewById(R.id.rpc_response_text);
    mResultText.setMovementMethod(new ScrollingMovementMethod());
    mHostEdit.setText("10.9.11.9");
    mPortEdit.setText("50051");
    mMessageEdit.setText("Test!");

    Log.d(TAG, "Created: " + R.layout.activity_main);
  }

  public void sendMessage(View view) {
    Log.d(TAG, "sendMessage: " + view);
  }

  private class RpcTask extends AsyncTask<Void, Void, String> {

    private String mHost;
    private String mMessage;
    private int mPort;

    @Override
    protected void onPreExecute() {
      mHost = mHostEdit.getText().toString();
      mMessage = mMessageEdit.getText().toString();
      String portStr = mPortEdit.getText().toString();
      mPort = TextUtils.isEmpty(portStr) ? 0 : Integer.valueOf(portStr);
      mResultText.setText("");
      Log.d(TAG, "onPreExecute: " + mHost);
    }

    @Override
    protected String doInBackground(Void... nothing) {
      Log.d(TAG, "doInBackground: <1>");
      try {
        return "Foo!";
      } catch (Exception e) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        e.printStackTrace(pw);
        pw.flush();
        return String.format("Failed... : %n%s", sw);
      }
    }

    @Override
    protected void onPostExecute(String result) {
      mResultText.setText(result);
      mSendButton.setEnabled(true);
    }

  }

}
