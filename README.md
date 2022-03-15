# Translator

This app is written in OverScript.
The script translates texts from one language to another using the [Yandex Translate API].\
You need to have an [OAuth token] to access the API and know the [folder ID]. This data must be entered in settings.ini. For example:
```
OAuthToken= AQAAAAA1e6U8AATuwUP6C9sUjkibxdD4vgKYCuE	#my token to access Yandex Cloud
FolderId= b1jljoxcem0ffc0l7k9m	#my folder ID 
Lang1= ru	#I want to translate from Russian 
Lang2= en	#into English
Dir1= G:\docs\texts	#folder with files to translate
Dir2= G:\docs\texts\result	#folder in which to save translated files
SkipBad= False	#don't skip. In case of an error, offer actions to choose from
RemBad= False	#don't delete files that failed to translate
RemGood= False	#don't delete files that are successfully translated
TransTag= translate	#I want to translate only the parts of the text that is inside <translate></translate>
RemTransTag= True	#remove <translate> and </translate> from result
TimeoutWhen429= 2	#wait 2 minutes if the API returned a 429 error (limit exceeded)
SaveErrorList= True	#save a list of files that failed to translate
```
To translate all text make the setting TransTag empty:
`TransTag=`\
Strings can be quoted: 
`Dir1= "G:\\docs\\texts"`


[Yandex Translate API]: https://yandex.ru/dev/translate/

[OAuth token]: https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token

[folder ID]: https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id

