"""Build isolated recording samples from the unchanged source fixtures. Run from repo root."""
from pathlib import Path
import json,copy
root=Path('.'); out=root/'assets/mocks/recording';out.mkdir(exist_ok=True)
def read(p):return json.loads((root/'assets/mocks'/p).read_text())
def write(name,j): (out/name).write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def spans(s):return [{'type':'text','text':s}]
# Prototype challenge wording plus knowledge from the bundled Salah lesson.
questions=[
('How many prayers are obligatory each day and night?','كم صلاة فُرضت في اليوم والليلة؟',['Three','Five','Seven'],['ثلاث','خمس','سبع'],1,'Muslims pray five obligatory prayers each day and night.','يصلي المسلم خمس صلوات مفروضة في اليوم والليلة.'),
('Which prayer comes just after sunset?','أي صلاة تأتي بعد غروب الشمس؟',['Fajr','Asr','Maghrib','Isha'],['الفجر','العصر','المغرب','العشاء'],2,'Maghrib begins after sunset.','يبدأ وقت المغرب بعد غروب الشمس.'),
('What did the Prophet ﷺ liken the five prayers to?','بماذا شبّه النبي ﷺ الصلوات الخمس؟',['A lamp in the night','A river at your door','A tree with deep roots'],['مصباح في الليل','نهر على باب البيت','شجرة جذورها عميقة'],1,'The river comparison illustrates how regular prayer washes away sins.','يوضح تشبيه النهر كيف تمحو الصلاة المنتظمة الخطايا.'),
('Which prayer is performed before sunrise?','أي صلاة تؤدّى قبل شروق الشمس؟',['Fajr','Dhuhr','Isha'],['الفجر','الظهر','العشاء'],0,'Fajr is the dawn prayer, before sunrise.','الفجر صلاة الصباح قبل شروق الشمس.'),
('Which prayer follows Dhuhr?','أي صلاة تأتي بعد الظهر؟',['Maghrib','Fajr','Asr'],['المغرب','الفجر','العصر'],2,'The daily order is Fajr, Dhuhr, Asr, Maghrib and Isha.','ترتيب الصلوات اليومية: الفجر والظهر والعصر والمغرب والعشاء.'),
('What is Salah?','ما الصلاة؟',['A regular act of worship','Only a social gathering','A yearly celebration'],['عبادة منتظمة','لقاء اجتماعي فقط','احتفال سنوي'],0,'Salah is worship that renews a Muslim’s connection with God throughout the day.','الصلاة عبادة تجدد صلة المسلم بالله طوال اليوم.'),
('What should a prayer timetable help you find?','ما الذي يساعدك جدول مواقيت الصلاة على معرفته؟',['The local prayer times','A person’s nationality','The number of friends online'],['مواقيت الصلاة في مكانك','جنسية الشخص','عدد الأصدقاء المتصلين'],0,'Prayer times depend on the time of day and your location.','ترتبط مواقيت الصلاة بوقت اليوم ومكانك.')]
script=read('contract/challenges/group_ws_script.json'); qt=next(x['data'] for x in script if x['type']=='question');rt=next(x['data'] for x in script if x['type']=='question_result')
for lang in ['en','ar']:
 events=[]
 for i,row in enumerate(questions):
  prompt,options,explanation=(row[0],row[2],row[5]) if lang=='en' else (row[1],row[3],row[6])
  q=copy.deepcopy(qt);e=q['exercise'];e['exercise_id']=f'ex_recording_{i}';e['concept_ids']=['con_salah'];e['prompt']=spans(prompt);e['payload']['options']=[{'option_id':f'opt_{n}','spans':spans(v)} for n,v in enumerate(options)];q['question_index']=i;q['total']=len(questions)
  r=copy.deepcopy(rt);r['question_index']=i;r['correct_answer']={'option_id':f'opt_{row[4]}'};r['explanation']=spans(explanation)
  events.extend([{'type':'question','data':q},{'type':'question_result','data':r}])
 write(f'challenges_{lang}.json',events)
 # Meaningful bilingual review deck based on glossary content.
 glossary=read(f'glossary/glossary_{lang}_explorer.json');terms=glossary['items'];base=read('contract/sessions/review_cards.json'); quick=read('contract/sessions/review_quick.json')
 cards=[];qs=[];keys={}
 for i,t in enumerate(terms[:12]):
  card=copy.deepcopy(base['items'][0]);e=card['exercise'];eid=f'ex_recording_card_{i}';card['block_id']=f'b_recording_card_{i}';e['exercise_id']=eid;e['concept_ids']=['con_salah'];e['scoring']={'accuracy':False,'combo':False,'layer':None};e['prompt']=spans('Recall the meaning, then turn the card.' if lang=='en' else 'تذكّر المعنى، ثم اقلب البطاقة.');e['payload']['front']=spans(('What does “'+t['text']+'” mean?') if lang=='en' else ('ما معنى «'+t['text']+'»؟'));e['payload']['back']=t['definition'];cards.append(card);keys[eid]={'answer_key':None}
  q=copy.deepcopy(quick['items'][0]);qe=q['exercise'];q['block_id']=f'b_recording_quick_{i}';qe['exercise_id']=f'ex_recording_quick_{i}';qe['prompt']=spans(('Which definition fits “'+t['text']+'”?') if lang=='en' else ('أي تعريف يناسب «'+t['text']+'»؟'));qe['payload']['options']=[{'option_id':f'opt_{n}','spans':terms[(i+n)%len(terms)]['definition']} for n in range(min(3,len(terms)))];qs.append(q);keys[qe['exercise_id']]={'answer_key':{'option_id':'opt_0'},'explanation':t['definition'],'source_ids':[]}
 for name,s,items in [('cards',base,cards),('quick',quick,qs[:3])]:
  s['title']=('Your words' if name=='cards' else 'Quick review') if lang=='en' else ('كلماتك' if name=='cards' else 'مراجعة سريعة');s['items']=items;s['counts']={'interactions':len(items),'exercises':len(items),'scored':0 if name=='cards' else len(items)};s['total_exercises']=len(items);write(f'review_{name}_{lang}.json',s)
 write(f'review_keys_{lang}.json',keys)
 # Three full pairs use existing Unit 0 lesson bodies, with alternative block order.
 pairs=[]
 for i in range(1,4):
  s=read(f'unit0/sessions/session_u0_l{i:02}_{lang}_explorer.json');notices=read('unit0/DRAFT_NOTICES.json');items=[b for b in s['items'] if b['block_id'] not in notices['block_ids_by_lesson'].get(s['lesson_id'],[])]
  a={k:s[k] for k in ['title','objectives','completion']};a['items']=items
  b=copy.deepcopy(a);teach=[n for n,x in enumerate(b['items']) if x['type']=='teach']
  if len(teach)>1: b['items'][teach[0]],b['items'][teach[1]]=b['items'][teach[1]],b['items'][teach[0]]
  pairs.append({'pair_id':f'pair_recording_{i}','lesson_a':a,'lesson_b':b})
 write(f'blind_{lang}.json',pairs)

# Static SVG illustrations, authored with the app's palette. No people or text.
(out/'museum.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500"><defs><linearGradient id="wall" x2="0" y2="1"><stop stop-color="#EAF4EF"/><stop offset="1" stop-color="#B8DAD1"/></linearGradient></defs><rect width="800" height="500" fill="url(#wall)"/><path d="M0 380H800V500H0Z" fill="#DCD5BD"/><path d="M110 380V170Q110 65 210 65Q310 65 310 170V380M490 380V170Q490 65 590 65Q690 65 690 170V380" fill="#0B4944" stroke="#E8C881" stroke-width="12"/><path d="M210 0V95M590 0V95" stroke="#BD9850" stroke-width="6"/><path d="M185 95H235L245 155H175ZM565 95H615L625 155H555Z" fill="#E8C881"/><g stroke="#76AA9F" stroke-width="3" fill="none"><path d="M350 100L400 50L450 100L400 150ZM350 230L400 180L450 230L400 280ZM350 360L400 310L450 360L400 410Z"/><path d="M365 65H435V135H365ZM365 195H435V265H365ZM365 325H435V395H365Z"/></g><path d="M0 435H800M160 380L90 500M400 380V500M640 380L710 500" stroke="#B5B59B" stroke-width="3"/></svg>''')
(out/'dawn.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500"><defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#0B4944"/><stop offset=".75" stop-color="#D7BB7D"/><stop offset="1" stop-color="#F3E7C7"/></linearGradient></defs><rect width="800" height="500" fill="url(#sky)"/><circle cx="560" cy="280" r="60" fill="#F3D896"/><path d="M0 325Q200 250 420 320T800 310V500H0Z" fill="#BBA075"/><path d="M0 390Q240 320 430 400T800 375V500H0Z" fill="#D8C19B"/><path d="M130 405L240 305L345 405Z" fill="#EAF4EF"/><path d="M240 305L290 405H345Z" fill="#9DB7AB"/><path d="M215 405L240 345L265 405Z" fill="#0B4944"/><path d="M120 408H355" stroke="#876F52" stroke-width="4"/></svg>''')
# Recording-specific run: actual Unit 0 scene-backed exports; unverified evidence stays blocked.
r=read('reviewer/u1l1.factory_run.json');r['run_id']='run_recording';r['plan']['title']={'en':'What Does Islam Mean? · Recording sample','ar':'ما معنى الإسلام؟ · نموذج التصوير'}
# Same draft, sentences, exercises and evidence as the supplied lesson. Only media is projected.
def replace_media(v):
 if isinstance(v,dict):
  for k,x in v.items():
   if k=='url' and isinstance(x,str):
    if x.endswith('/museum_gallery.webp'):v[k]='https://recording.qabas.invalid/museum.png';v['mime_type']='image/png'
    elif x.endswith('/desert_dawn.webp'):v[k]='https://recording.qabas.invalid/dawn.png';v['mime_type']='image/png'
   else:replace_media(x)
 elif isinstance(v,list):
  for x in v:replace_media(x)
replace_media(r['draft'])
for v in r['draft']['visuals']:v['audit']={'passed':False,'issues':['Recording illustration only; publication audit remains pending.']}
# Retain the substantive evidence blockers; sample art does not certify publication.
for issue in r['qa_report']['issues']:
 if 'visual' in issue['message'].lower() or 'media' in issue['message'].lower() or 'image' in issue['message'].lower():
  issue['message']='Recording illustration is available locally; production asset audit and publication remain pending.'
write('factory_run.json',r)
g=copy.deepcopy(r);g['run_id']='run_recording_plan';g['status']='awaiting_gate1';g['stage']='plan';g['draft']=None;g['qa_report']=None;write('factory_plan.json',g)
# Bilingual answers to the four actual suggestion chips. Evidence is sourced from existing exports.
for lang in ['en','ar']:
 a=read('examples/RaqeebCompleted__get_raqeeb_messages_message_id__3.json');a['classification']['label']='General knowledge' if lang=='en' else 'سؤال معرفي';a['terms']={};a['suggested_lessons']=[]
 if lang=='en':
  a['blocks']=[{'type':'paragraph','spans':spans('Muslims pray five obligatory prayers each day and night: Fajr, Dhuhr, Asr, Maghrib and Isha. Prayer renews their connection with God throughout the day.')+[{'type':'citation','ref':1}]}]
  for c in a['citations']:
   c['source']['title']='The five daily prayers' if c['ref']==2 else 'Hadith: Islam is built on five pillars';c['source']['reference']='Sahih al-Bukhari (8), Sahih Muslim (16)' if c['ref']==1 else 'IslamHouse'
 a['suggested_lessons']=[{'lesson_id':'les_u1_l3','title':'Prayer' if lang=='en' else 'الصلاة'}];write(f'raqeeb_prayer_{lang}.json',a)
 # Known authentic river comparison in the bundled Salah evidence, not unrelated verification sample.
 s=read(f'salah/session_salah_{lang}_explorer.json')
 evidence=[]
 def visit(v):
  if isinstance(v,dict):
   if 'text_uthmani' in v and v.get('kind')=='hadith':evidence.append(v)
   for x in v.values():visit(x)
  elif isinstance(v,list):
   for x in v:visit(x)
 visit(s)
 b=copy.deepcopy(a);b['classification']={'question_class':'verification','label':'Hadith verification' if lang=='en' else 'التحقق من الحديث'}
 b['blocks']=[{'type':'paragraph','spans':spans('The comparison of the five prayers to a river at one’s door is reported by al-Bukhari and Muslim. It describes the cleansing effect of regular prayer.') if lang=='en' else spans('تشبيه الصلوات الخمس بنهر على باب أحدكم مروي في البخاري ومسلم، ويبين أثر الصلاة في محو الخطايا.')}]
 src=next((v for v in s['sources'].values() if '4968' in str(v)),None) if isinstance(s['sources'],dict) else next((v for v in s['sources'] if '4968' in str(v)),None)
 if src:
  b['citations']=[{'ref':1,'source':src}];b['blocks'][0]['spans'].append({'type':'citation','ref':1})
 else:b['citations']=[]
 verification=copy.deepcopy(read('examples/RaqeebCompleted__get_raqeeb_messages_message_id__4.json')['blocks'][0])
 item=verification['items'][0];item['quote_text']='The five prayers are like a river at your door.' if lang=='en' else 'الصلوات الخمس كنهر على باب أحدكم'
 item['hadith_grade']={'grade_label':'Authentic' if lang=='en' else 'صحيح','grade_category':'authentic','grader':'al-Bukhari and Muslim' if lang=='en' else 'البخاري ومسلم','source_book':'Agreed upon' if lang=='en' else 'متفق عليه','reference':None}
 item['alternative']=None;item['note']=b['blocks'][0]['spans'][:1];item['source_ids']=[src['source_id']] if src else []
 b['blocks'].append(verification)
 write(f'raqeeb_hadith_{lang}.json',b)
 c=copy.deepcopy(a);c['blocks']=[{'type':'paragraph','spans':spans('Islam means willing submission to God. It describes a relationship with God expressed through belief and action, rather than belonging to a particular people or inheriting a family identity.') if lang=='en' else spans('الإسلام هو الاستسلام لله عن اختيار. وهو علاقة بالله تظهر في الإيمان والعمل، وليس انتماءً إلى قوم معينين أو هوية موروثة من الأسرة.')}];c['citations']=[];c['suggested_lessons']=[{'lesson_id':'les_u1_l1','title':'What Does Islam Mean?' if lang=='en' else 'ما معنى الإسلام؟'}];write(f'raqeeb_islam_{lang}.json',c)
 d=read('examples/RaqeebCompleted__get_raqeeb_messages_message_id__5.json');d['understood_input']={'transcript':None,'images':[],'document':None};d['blocks'][0]['referral']['reason']=spans('يحتاج سؤالك عن الصلاة أثناء تعلم العربية إلى توجيه يناسب ظروفك من معلّم مؤهل أو جهة إفتاء معتمدة.')
 if lang=='en':
  d['classification']['label']='Personal question';d['blocks']=[{'type':'paragraph','spans':spans('Learning to pray takes practice. For guidance that fits your circumstances while you learn Arabic, ask a qualified teacher or specialist. I cannot issue a personal ruling.')}]+[x for x in d['blocks'] if x['type']=='referral']
  def translate(v):
   if isinstance(v,dict):
    for k,x in v.items():
     if isinstance(x,str) and any('\u0600'<=ch<='\u06ff' for ch in x) and k not in ['text_uthmani']:
      v[k]={'title':'Ask a qualified specialist','body':'A qualified specialist can help with your circumstances.','text':'A qualified specialist can help with your circumstances.','label':'Personal question','reason':'This question needs personal guidance.'}.get(k,'Personal prayer guidance')
     else:translate(x)
   elif isinstance(v,list):
    for x in v:translate(x)
  translate(d);d['citations']=[];d['terms']={};d['suggested_lessons']=[]
 write(f'raqeeb_arabic_{lang}.json',d)
 fallback=copy.deepcopy(d);fallback['classification']={'question_class':'out_of_scope','label':'Outside the sample questions' if lang=='en' else 'خارج الأسئلة المتاحة'};fallback['abstained']=True;fallback['blocks']=[{'type':'paragraph','spans':spans('Choose one of the suggested questions to explore an answer with sources.') if lang=='en' else spans('اختر أحد الأسئلة المقترحة لاستكشاف إجابة مع مصادر.')}];fallback['citations']=[];fallback['terms']={};fallback['suggested_lessons']=[];write(f'raqeeb_other_{lang}.json',fallback)

# Rasterize these code-authored vectors to the contract's supported PNG type.
try:
 import cairosvg
except ImportError:
 if not all((out/(name+'.png')).exists() for name in ['museum','dawn']):
  raise SystemExit('Install cairosvg for the first recording-illustration build.')
else:
 for name in ['museum','dawn']:
  cairosvg.svg2png(url=str(out/(name+'.svg')),write_to=str(out/(name+'.png')),output_width=1600,output_height=1000)
