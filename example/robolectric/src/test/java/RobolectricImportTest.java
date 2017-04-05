/**
 * This file is not a functional robolectric test.  It is present to
 * test the import statements (from the maven_repository rule).
 */

// import android.app.Activity;
// import android.widget.Button;
// import android.widget.EditText;
// import android.widget.TextView;

//import example.activity.MyActivity;
//import example.activity.BuildConfig;
//import example.activity.R;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

import static org.hamcrest.Matchers.equalTo;
import static org.junit.Assert.assertThat;

//@RunWith(RobolectricTestRunner.class)
//@Config(constants = BuildConfig.class)
public class RobolectricImportTest {

  @Test
  public void clickingButton_shouldChangeResultsViewText() throws Exception {
    //Activity activity = Robolectric.setupActivity(MyActivity.class);
    //Button button = (Button) activity.findViewById(R.id.host_edit_text);
    //TextView results = (TextView) activity.findViewById(R.id.rpc_response_text);
    //button.performClick();
    //assertThat(results.getText().toString(), equalTo("Foo!"));

    assertThat("Foo!", equalTo("Foo!"));
  }

}
