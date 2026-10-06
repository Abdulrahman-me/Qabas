"""Generate the plain reviewer records from the checked-in revision 10 schema.
Learner content stays in the shared typed renderer models. No contract files are modified.
"""
import json,re
from pathlib import Path
schema=json.load(open('docs/contract/03_API/contract_revision10/contract/qabas_contract.schema.json'))
defs={}
for root,s in schema.items():
 defs.update(s.get('$defs',{})); defs[root]={k:v for k,v in s.items() if k!='$defs'}
external={'Source':('Source','SourceDto','toEntity()'),'Visual':('Visual','VisualDto','toEntity()'),'Completion':('LessonCompletion','CompletionDto','reviewCompletion()'),'Exercise':('Exercise','ExerciseHeaderDto','toEntity()'),'Evidence':('Evidence','EvidenceDto','toEntity()')}
span_refs=['SpanText','SpanStrong','SpanTerm','SpanCitation']
block_refs=['BHook','BPredict','BStory','BTeach','BParagraph','BEvidence','BVisual','BCallout','BExercise']
def camel(s): return re.sub(r'_([a-z])',lambda m:m[1].upper(),s)
def unwrap(s):
 if isinstance(s,bool):s={}
 if 'anyOf' in s:
  opts=[o for o in s['anyOf'] if o.get('type')!='null']
  if len(opts)==1:return opts[0],len(opts)!=len(s['anyOf'])
 return s,False
seen=set()
def typ(s,dto=False):
 s = {} if isinstance(s,bool) else s
 s,n=unwrap(s); suffix='?' if n else ''
 if '$ref' in s:
  name=s['$ref'].split('/')[-1]
  if name in external:return external[name][1 if dto else 0]+suffix
  if name in span_refs:return ('SpanDto' if dto else 'ContentSpan')+suffix
  if name in block_refs:return ('BlockDto' if dto else 'SessionItem')+suffix
  visit(name);return 'Review'+name+('Dto' if dto else '')+suffix
 if 'oneOf' in s or 'anyOf' in s:
  opts=s.get('oneOf',s.get('anyOf')); refs=[o.get('$ref','').split('/')[-1] for o in opts]
  if set(refs)<=set(span_refs):return 'SpanDto' if dto else 'ContentSpan'
  if set(refs)<=set(block_refs):return 'BlockDto' if dto else 'SessionItem'
  raise ValueError(('union',s))
 t=s.get('type')
 if t=='array':return 'List<'+typ(s['items'],dto)+'>'+suffix
 if t=='object':return 'Map<String, '+typ(s.get('additionalProperties',{}),dto)+'>'+suffix
 return {'string':'String','integer':'int','number':'double','boolean':'bool'}.get(t,'Object')+suffix

def visit(name):
 if name in seen or name in external:return
 seen.add(name)
 for key,s in defs[name].get('properties',{}).items():
  if name=='ReviewerExercise' and key in ['payload','answer_key']:continue
  typ(s)
# ReviewerExercise is decoded through the existing ExerciseDto; private key remains data-layer decoded.
seen.add('ReviewerExercise')
for n in ['FactoryRun','Gate1','Gate2','RunCreate','RunRow','BlindPair','BlindAnswer','Metrics','DraftFragment','ReviewerReq']:visit(n)
seen.remove('ReviewerExercise')
domain=["import 'package:equatable/equatable.dart';","import 'package:qabas/shared/domain/entities/content.dart';","import 'package:qabas/shared/lesson/domain/entities/session.dart';","import 'package:qabas/shared/lesson/domain/entities/exercise.dart';"]
dto=["import 'package:json_annotation/json_annotation.dart';","import 'package:qabas/shared/data/dtos/content_dto.dart';","import 'package:qabas/shared/data/mappers/content_mappers.dart';","import 'package:qabas/shared/lesson/data/dtos/session_dto.dart';","import 'package:qabas/shared/lesson/data/mappers/session_mappers.dart';","import 'package:qabas/shared/lesson/data/mappers/exercise_mappers.dart';","import 'package:qabas/shared/lesson/domain/entities/session.dart';","import 'package:qabas/features/reviewer/domain/reviewer_models.dart';","part 'reviewer_dtos.g.dart';"]
def conv(s,v):
 u,n=unwrap(s)
 if n:return f'{v} == null ? null : '+conv(u,v+'!')
 if '$ref' in u:
  name=u['$ref'].split('/')[-1]
  return v+'.'+external.get(name,('','','toEntity()'))[2]
 if u.get('type')=='array':
  if typ(u['items'],True)=='SpanDto':return f'contentSpans({v})'
  return f'{v}.map((e) => {conv(u["items"],"e")}).toList()'
 if u.get('type')=='object':return f'{v}.map((k, e) => MapEntry(k, {conv(u.get("additionalProperties",{}),"e")}))'
 if 'oneOf' in u or 'anyOf' in u:return v+'.toEntity()'
 return v
for name in sorted(seen):
 props=defs[name].get('properties',{})
 cn='Review'+name
 fields=[(camel(k),s) for k,s in props.items()]
 domain.append(f'final class {cn} extends Equatable {{')
 args=', '.join('required this.'+k if not typ(s).startswith(('List<','Map<')) else 'required '+typ(s)+' '+k for k,s in fields)
 inits=', '.join(k+' = '+('List.unmodifiable('+k+')' if typ(s).startswith('List<') else 'Map.unmodifiable('+k+')') for k,s in fields if typ(s).startswith(('List<','Map<')))
 domain.append(('const ' if not inits else '')+f'{cn}({{{args}}})'+(' : '+inits if inits else '')+';')
 for k,s in fields:domain.append(f'final {typ(s)} {k};')
 domain.append(f'{cn} copyWith({{{", ".join(typ(s).rstrip("?")+"? "+k for k,s in fields)}}}) => {cn}('+', '.join(k+': '+k+' ?? this.'+k for k,s in fields)+');')
 domain.extend(['@override',f'List<Object?> get props => [{", ".join(k for k,s in fields)}];','}'])
 dto.extend(['@JsonSerializable()',f'final class {cn}Dto {{',f'const {cn}Dto({{{", ".join("required this."+k for k,s in fields)}}});',f'factory {cn}Dto.fromJson(Map<String,dynamic> json) => _${cn}DtoFromJson(json);'])
 for k,s in fields:dto.append(f'final {typ(s,True)} {k};')
 dto.append(f'{cn} toEntity() => {cn}('+', '.join(k+': '+conv(s,k) for k,s in fields)+');')
 dto.append('}')
# Private reviewer exercise projection with typed learner exercise and answer.
domain.append('''final class ReviewReviewerExercise extends Equatable {
 ReviewReviewerExercise(this.exercise, this.answerKey, Map<String,String> optionMisconceptions, this.duelEligible): optionMisconceptions=Map.unmodifiable(optionMisconceptions);
 final Exercise exercise; final AnswerPayload? answerKey; final Map<String,String> optionMisconceptions; final bool duelEligible;
 @override List<Object?> get props => [exercise,answerKey,optionMisconceptions,duelEligible];
}''')
dto.append('''final class ReviewReviewerExerciseDto {
 ReviewReviewerExerciseDto(this.exercise,this.key,this.misconceptions,this.eligible);
 factory ReviewReviewerExerciseDto.fromJson(Map<String,dynamic> j) => ReviewReviewerExerciseDto(ExerciseHeaderDto.fromJson(j),j['answer_key'] as Map<String,dynamic>?,Map<String,String>.from(j['option_misconceptions'] as Map),j['duel_eligible'] as bool);
 final ExerciseHeaderDto exercise; final Map<String,dynamic>? key; final Map<String,String> misconceptions; final bool eligible;
 ReviewReviewerExercise toEntity() {final e=exercise.toEntity();return ReviewReviewerExercise(e,correctAnswer(e.type,key),misconceptions,eligible);}
}
extension ReviewerCompletionMapping on CompletionDto {
 LessonCompletion reviewCompletion() => LessonCompletion(challenge:contentSpans(challenge),reviewTopics:reviewTopics.map((e)=>ReviewTopic(topicId:e.topicId,title:e.title,conceptIds:e.conceptIds)).toList(),checkIn:contentSpans(checkIn));
}''')
for path,lines in [('lib/features/reviewer/domain/reviewer_models.dart',domain),('lib/features/reviewer/data/reviewer_dtos.dart',dto)]:
 p=Path(path);p.parent.mkdir(parents=True,exist_ok=True);p.write_text('\n'.join(lines)+'\n')
print('Generated',len(seen),'typed reviewer records')
encoder=["import 'package:qabas/features/reviewer/domain/reviewer_models.dart';"]
encoded=set()
def encode_type(s,v):
 u,n=unwrap(s)
 if n:return f'{v} == null ? null : '+encode_type(u,v+'!')
 if '$ref' in u:
  name=u['$ref'].split('/')[-1];encode(name);return f'encodeReview{name}({v})'
 if u.get('type')=='array':return f'{v}.map((e)=>{encode_type(u["items"],"e")}).toList()'
 return v
def encode(name):
 if name in encoded:return
 encoded.add(name)
 fields=defs[name]['properties']; vals=[f"'{k}': {encode_type(s,'v.'+camel(k))}" for k,s in fields.items()]
 encoder.append(f'Map<String,Object?> encodeReview{name}(Review{name} v)=>{{'+', '.join(vals)+'};')
for n in ['Gate1','Gate2','RunCreate','BlindAnswer']:encode(n)
Path('lib/features/reviewer/data/reviewer_requests.dart').write_text('\n'.join(encoder)+'\n')
