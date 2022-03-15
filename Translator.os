#app Translator, Version="1.0.0"

string IAMToken;
string LastError = "";
int CurrentFileNum;
StrList ErrList = new StrList();

Settings.Load();
string[] Files = GetFiles(Settings.Dir1);
int FileCount = Files.Length();


StartTranslate();


string Status(){
	string str = (CurrentFileNum + 1) + "/" + FileCount + ". Bad: " + ErrList.Count + ". ";
	if(LastError != "") str += " Error: " + LastError;
	return str;
}

StartTranslate()
{
	WriteLine("Getting an IAM token...");
	IAMToken = "";
	try
	{
		IAMToken = GetIAMToken(Settings.OAuthToken);
	}
	catch
	{
		ReadKey(exMessage);
	}
	
	if (IAMToken == "") return;

	string text, sf;

	ErrList.Clear();
	string tt = Settings.TransTag;
	string f;
	
	for (CurrentFileNum = 0; CurrentFileNum < FileCount; CurrentFileNum++)
	{
		f = Files[CurrentFileNum];
		WriteLine("Translation " + Status());
		
	GoTrans:
		try
		{
		
			LastError = "";
			text = ReadAllText(f);
			string[] results;
			if (tt != "")
			{
				StrList texts = new StrList();

				string[] textsToTranslate = GetTexts(text,tt);
				if(textsToTranslate == null) throw("EmptyText", "No text to translate.");
				results = Translate(textsToTranslate);
				
				int n = 0;
				int i = text.IndexOf("<" + tt + ">");
				int ttLen = tt.Length();
				int i2;
				while (i >= 0)
				{
					i2 = text.IndexOf("</" + tt + ">", i);
					if (Settings.RemTransTag) text = text.Left(i) + results[n++] + text.Substring(i2 + ttLen + 3);
					else text = text.Left(i + Length(tt) + 2) + results[n++] + text.Substring(i2);

					i = text.IndexOf("<" + tt + ">", i + 1);
				}
			}
			else {
				if(text.Trim() == "") throw("EmptyText", "No text to translate.");
				results = Translate(new string[] { text });
				text = results[0]; 
			}
			
			if (Settings.Dir2 != "") sf = CombinePath(Settings.Dir2, GetFileName(f)); else sf = f;
			WriteAllText(sf, text);
			if (Settings.RemGood) DeleteFile(f);
		}
		catch
		{
			if (!Settings.SkipBad)
			{
				WriteLine("Error on file \"" + GetFileName(f) + "\". " + exMessage);
				WriteLine("Cancel - C, retry - R, skip - any key.");
				string key := ReadKey(true);
		
				if (key == "R") {WriteLine("Retry..."); goto GoTrans; }
				if (key == "C") {WriteLine("Cancel..."); break; }
				WriteLine("Skip and continue...");
			}
			if (Settings.RemBad) DeleteFile(f);
  
			string errMsg;
			int j2, j = exMessage.IndexOf("\"message\":");
			if(j >= 0){ 
				j += 12;
				j2 = exMessage.IndexOf("\"", j);
				errMsg = exMessage.Substring(j, j2 - j);
			}else
				errMsg = exMessage.Replace("\r\n", " ").Left(75) + "...";

			ErrList.Add(GetFileName(f) + "\t" + errMsg);
			LastError = errMsg;
		}
	}

	string errors = Join("\r\n", ErrList.Items);
	while(errors.IndexOf("\r\n\r\n") >= 0) errors = errors.Replace("\r\n\r\n", "");

	if (Settings.SaveErrorList && ErrList.Count > 0){
		WriteLine("Saving a list of unsuccessful..."); 
		WriteAllText("ErrorList.txt", errors); 
	}
	WriteLine("Completed. Status: " + CurrentFileNum + "/" + FileCount + ". Bad: " + ErrList.Count + ". ");
	if(ErrList.Count > 0) WriteLine("\r\nUnsuccessful:\r\n" + errors.Replace("\t", " - ") + "\r\n");
	WriteLine("Press any key to exit.");
	ReadKey();
}


string[] GetTexts(string text,string tt)
{
	string tag = "<" + tt + ">";
	int tagLen = tag.Length();
	if(text.IndexOf(tag) < 0) return null;
	string[] texts = text.Split("</" + tt + ">");
	int c = texts.Length() - 1;
	for(int i = 0; i < c; i++) texts[i] = texts[i].Substring(texts[i].IndexOf(tag) + tagLen);
	if(c > 0) texts.Resize(c);
	return texts;
}

string[] Translate(string[] texts)
{
	string[] result;
	string json = ToJson(new TranslateData(texts), true);
	string data = GoAPI("https://translate.api.cloud.yandex.net/translate/v2/translate", json, IAMToken);
	int i = data.IndexOf("\"text\": \"");

	if (i >= 0)
	{
		i = data.IndexOf("\r\n\r\n");
		string jobj = data.Substring(i + 4);

		JResp jc = FromJson(jobj, JResp);

		result = jc.translations.Select(JResp.JText item, item.text);
	}
	else
	{
		throw("FailedToReceiveTranslation", "Unable to receive translation! Server response:\r\n\r\n" + data);

	}

	return result;
}

string GetIAMToken(string OAuthToken){
	string token = "";
	string json = ToJson(new YaOAuthToken(OAuthToken), true);

	string data = GoAPI("https://iam.api.cloud.yandex.net/iam/v1/tokens", json);
	int i2, i = data.IndexOf("\"iamToken\": \"");

	if (i >= 0) {
		i2 = data.IndexOf("\"",  i + 13); 
		token = data.Substring(i + 13, i2 - (i + 13));
	}else{
	
		throw("FailedToGetIAMToken", "Failed to get IAM token! Server response:\r\n\r\n" + data);

	}
	return token;
}

string GoAPI(string url, string json, string token = ""){

	string httpResponse;
	int tryNum;
	int httpCode;
	bool tryMore;
	string headers = "";
	if (token != "") headers += "Authorization: Bearer " + token;

	do
	{

		if (++tryNum > 1) Sleep(500);
		try{
			
			httpResponse = Fetch(url, headers,,, "AllowAutoRedirect=TRUE, MaxAutomaticRedirections=2", json,, "application/json");
		}
		catch{httpResponse = "";}

		httpCode = GetHTTPStatusCode(httpResponse);

		tryMore = false;
		if (httpCode == 429)
		{
			int sec = Settings.TimeoutWhen429 * 60;
			string limInfo = "Pause (limit reached)... Seconds left: ";
			int limInfoLen = limInfo.Length();
			Write(limInfo);
	
			do
			{
				SetCursorLeft(limInfoLen);
				Write(PadRight(sec.ToString(), 3));
				Sleep(1000);
				sec--;
			} while (sec >= 0);
		
			WriteLine();
			WriteLine("Continued... Translation " + Status());
			tryMore = true;
		}
		else if (httpCode == 401)
		{
			if (tryNum < 3) {
	 
				WriteLine("IAM token refresh...");
				token = IAMToken = GetIAMToken(Settings.OAuthToken);
				tryMore = true; 
				WriteLine("Continued... Translation " + Status()); 
				
			}
		}
	} while (tryMore || (httpCode != 200 && httpCode != 400 && tryNum < 2));


	return httpResponse;
}

int GetHTTPStatusCode(string text){
	int i = text.IndexOf(' ');
	if(i > 0){
		int i2 = text.IndexOf(' ', i + 1);
		if(i > 0){return text.Substring(i + 1, i2 - (i + 1)).ToInt();}
	}
}

static class Settings{
	public static string OAuthToken, FolderId;
	public static string Lang1, Lang2;
	public static string Dir1, Dir2;
	public static bool SkipBad, RemBad,RemGood, SaveErrorList, RemTransTag;
	public static string TransTag;
	public static int TimeoutWhen429;

	
	public static Load(){
		string ini = ReadAllText("settings.ini");
		OAuthToken = IniGet(ini, "OAuthToken");
		FolderId = IniGet(ini, "FolderId");
		Lang1 = IniGet(ini, "Lang1");
		Lang2 = IniGet(ini, "Lang2");
		Dir1 = IniGet(ini, "Dir1");
		Dir2 = IniGet(ini, "Dir2");
		SkipBad := IniGet(ini, "SkipBad");
		RemBad := IniGet(ini, "RemBad");
		RemGood := IniGet(ini, "RemGood");
		TransTag = IniGet(ini, "TransTag");
		RemTransTag := IniGet(ini, "RemTransTag");
		TimeoutWhen429 := IniGet(ini, "TimeoutWhen429");
		SaveErrorList := IniGet(ini, "SaveErrorList");
		
	}
}


class YaOAuthToken
{
	string yandexPassportOauthToken;
	New(string token){
		yandexPassportOauthToken = token;
	}
}

class JResp
{
	public JText[] translations;
	public class JText
	{
		public string text;
	}
}


class StrList{
	int Capacity;
	public int Count;
	public string[] Items;
	
	New(){
		Clear();
	}
	public Add(string v){
		if(Count >= Capacity - 1){Capacity *= 2; Resize(Items, Capacity);}
		Items[Count] = v;
		Count++;
		
	}
	public Clear(){
		Capacity = 10; 
		Count = 0;
		Items = new string[Capacity];
	}
	public Remove(int index){
		int c = Count - 1;
		for(int i = index; i < c; i++) Items[i] = Items[i + 1];
		Count = c;
	}
}

class TranslateData
{
	string sourceLanguageCode;
	string targetLanguageCode;
	string format;
	string[] texts;
	string folderId;
	New(string[] texts)
	{
		sourceLanguageCode = Settings.Lang1;
		targetLanguageCode = Settings.Lang2;
		format = "HTML";
		this.texts = texts;
		folderId = Settings.FolderId;
	}
}

		