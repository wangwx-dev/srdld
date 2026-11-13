extends RefCounted
class_name Loc

static func error_text(code: String) -> String:
	match code:
		"no_actions":
			return "今天的行动次数用完了。"
		"pending_event":
			return "先把眼前这件事处理完。"
		"not_playing":
			return "这一局已经结束。"
		"need_stamina":
			return "太累了，先休息。体力低于 8 时不能工作或出门。"
		"cant_afford":
			return "钱不够做这件事。"
		"bad_id":
			return "这个选项不存在。"
		"no_contract":
			return "现在没有进行中的赞助。"
		"no_offer":
			return "现在没有赞助邀约。"
		"no_event":
			return "现在没有待处理的事件。"
		"bad_choice":
			return "没有这个选择。"
		_:
			return "做不到：%s" % code


static func action_text(code: String, extra: Dictionary = {}) -> String:
	match code:
		"rest":
			return "休息了一阵，体力回来了一些，压力也下去了。"
		"outing":
			return "出了门。花了路费，换到灵感和心情。"
		"freelance":
			return "接了一单代笔，到账 %s。" % yuan(int(extra.get("money", 0)))
		"study_writing":
			return "上了一节写作课，写作技能上升了。"
		"study_editing":
			return "上了一节剪辑课，剪辑技能上升了。"
		"sponsor_accept":
			return "接下了%s的赞助，要在第 %d 天结束前交稿。" % [str(extra.get("brand", "品牌")), int(extra.get("due_day", 0))]
		"sponsor_reject":
			return "谢绝了%s。少一笔钱，口碑和心情好了一点。" % str(extra.get("brand", "对方"))
		"sponsor_expired":
			return "赞助邀约过期了，没有奖罚。"
		"sponsor_failed":
			return "赞助到点没交，报酬没了，口碑 -12，压力上升。"
		_:
			return code


static func log_line(entry: Dictionary, sim: CareerSim) -> String:
	var kind := str(entry.get("kind", ""))
	if kind == "post":
		var index := int(entry.get("post_index", -1))
		if index < 0 or index >= sim.posts.size():
			return "第%d天 · 一条发布" % int(entry.get("day", 0))
		return post_summary(sim.posts[index])
	if kind == "event":
		var choice := str(entry.get("choice", ""))
		if choice == "":
			return "第%d天 · %s" % [int(entry.get("day", 0)), str(entry.get("text", ""))]
		return "第%d天 · %s（%s）" % [int(entry.get("day", 0)), str(entry.get("text", "")), choice]
	return "第%d天 · %s" % [int(entry.get("day", 0)), action_text(str(entry.get("code", "")), entry)]


static func post_summary(post: Dictionary) -> String:
	return "第%d天 · %s · %s · 播放 %d · %s" % [
		int(post.get("day", 0)),
		str(post.get("platform_name", "")),
		str(post.get("topic_name", "")),
		int(post.get("views", 0)),
		yuan(int(post.get("ad_money", 0)) + int(post.get("sponsor_pay", 0))),
	]


static func factor_lines(result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("成品质 %s。写作、剪辑、灵感、心情、体力和压力都会先加进质量，再乘力度。" % num(float(result.get("quality", 0))))
	for factor in result.get("factors", []):
		var line := factor_line(factor)
		if line != "":
			lines.append(line)
	lines.append("播放 %d，规则区间 %d–%d。" % [int(result.get("views", 0)), int(result.get("view_low", 0)), int(result.get("view_high", 0))])
	lines.append("新粉丝 %d（区间 %d–%d）。广告收入 %s（区间 %s–%s）。" % [
		int(result.get("followers", 0)),
		int(result.get("follower_low", 0)),
		int(result.get("follower_high", 0)),
		yuan(int(result.get("ad_money", 0))),
		yuan(int(result.get("money_low", 0))),
		yuan(int(result.get("money_high", 0))),
	])
	var note := str(result.get("sponsor_note", "none"))
	if note != "none":
		lines.append(sponsor_line(note, int(result.get("sponsor_pay", 0)), float(result.get("sponsor_rep", 0))))
	lines.append("口碑合计 %s。其中内容本身只会小幅加减，赞助才会明显摇摆。" % signed_num(float(result.get("rep_delta", 0))))
	lines.append("消耗体力 %d，灵感 %d。" % [int(result.get("stamina_cost", 0)), int(result.get("inspiration_cost", 0))])
	return lines


static func factor_line(factor: Dictionary) -> String:
	var id := str(factor.get("id", ""))
	var amount := float(factor.get("amount", 0))
	match id:
		"base":
			return "起步质量 %s。" % num(amount)
		"writing":
			return "写作技能贡献 %s 质量。" % signed_num(amount)
		"editing":
			return "剪辑技能贡献 %s 质量。" % signed_num(amount)
		"editing_penalty":
			return "电脑还在卡，剪辑技能临时降 %s。上面的剪辑贡献已经扣过了。" % num(amount)
		"inspiration":
			return "灵感贡献 %s 质量。" % signed_num(amount)
		"mood":
			return "心情贡献 %s 质量。" % signed_num(amount)
		"stamina":
			return "当前体力贡献 %s 质量。" % signed_num(amount)
		"stress":
			return "压力改动质量 %s。" % signed_num(amount)
		"reputation":
			return "口碑修正质量 %s。" % signed_num(amount)
		"duel":
			return "你答应了热搜阿凯的同题，额外 %s 质量。这不是比赛奖金。" % signed_num(amount)
		"topic_bonus":
			return "街头题吃到了出门或高灵感，额外 %s 质量。" % signed_num(amount)
		"effort":
			return "力度系数 %s。" % mult(amount)
		"inspiration_low":
			return "灵感不够这个力度，质量再 %s。" % mult(amount)
		"stamina_low":
			return "体力撑不满这个力度，质量再 %s。" % mult(amount)
		"fit":
			return "选题和这个平台的契合 %s。" % mult(amount)
		"topic_fit_bonus":
			return "采风让契合再 %s。" % mult(amount)
		"trend":
			if bool(factor.get("matched", false)):
				return "踩中本周趋势「%s」，播放 %s。" % [str(factor.get("tag", "")), mult(amount)]
			return "没踩中本周趋势「%s」，播放 %s。" % [str(factor.get("tag", "")), mult(amount)]
		"fatigue":
			return "这个选题在该平台的新鲜度 %s（疲劳值 %s，越高越熟）。" % [mult(amount), num(float(factor.get("fatigue", 0)))]
		"format":
			if bool(factor.get("matched", false)):
				return "体裁正是这个平台爱看的，%s。" % mult(amount)
			return "体裁不是这个平台的主场，%s。" % mult(amount)
		"quality_reach":
			return "成品质转换成播放 %s。" % mult(amount)
		"reach_effort":
			return "力度对传播再 %s。" % mult(amount)
		"sponsor_view":
			return "带了赞助标记，播放 %s。" % mult(amount)
		"audience":
			return "基础受众 %s，等于平台冷启动加上你的粉丝重量。" % num(amount)
		"variance":
			if bool(factor.get("preview", false)):
				return "预览按波动 %s 估算。实发只在 ×0.94 到 ×1.06 里取一次，没有更大的隐藏随机。" % mult(amount)
			return "这次平台波动 %s。允许范围只有 ×0.94 到 ×1.06。" % mult(amount)
		"sponsor_pay", "sponsor_rep", "organic_rep":
			return ""
		_:
			return ""


static func sponsor_line(note: String, pay: int, rep: float) -> String:
	match note:
		"great":
			return "赞助和内容贴合，而且做得够好：赞助费 %s，口碑 %s。" % [yuan(pay), signed_num(rep)]
		"ok":
			return "赞助按约定交付：赞助费 %s，口碑 %s。" % [yuan(pay), signed_num(rep)]
		"sloppy":
			return "这条像硬广：赞助费只拿六成（%s），口碑 %s。" % [yuan(pay), signed_num(rep)]
		"mismatch":
			return "平台或标签没对上赞助要求：赞助费七成（%s），口碑 %s。" % [yuan(pay), signed_num(rep)]
		_:
			return ""


static func help_text() -> String:
	return """自媒体经营日记

你要独立做满 30 天。第 12 天交房租 800，第 22 天还助学贷款 650，第 30 天再交月末房租 900。每天结束时还要付 25 元伙食。哪一笔付不出，这个月就结束。全部付清并熬到第 30 天，算你站住了。

每天有 3 次行动：写稿发布、休息、出门采风、自由职业、学写作、学剪辑。体力低于 8 不能工作或出门。休息不赚钱，但能把压力和体力拉回来。只休息不做事，付不出账。

发布前能看到播放、收入和粉丝的区间。实际结果只会在这个区间里。影响播放的东西都会写出来：成品质、平台契合、体裁是否对口、本周趋势、选题疲劳，以及 ×0.94 到 ×1.06 的平台波动。没有隐藏的大暴击。

三个虚构平台口味不同。柿子视频吃短视频和趋势，青帖吃图文，长河吃长视频和剪辑，单次观看更值钱。同一选题连发会疲劳，换题或歇几天会恢复。趋势每 7 天换一次，下周趋势会提前告诉你。

赞助报酬是固定的。贴合并且做得够好，钱和口碑都在；硬做或不对题，钱变少、口碑下降。不接，则少赚钱、口碑略升。到点不交，报酬取消且口碑 -12。

热搜阿凯、慢半拍林、无名神人只是同城动静。「神人大乱斗」留到以后的赛季，本月不影响播放和账单。

操作：用鼠标或触控点按钮。Esc 暂停。暂停里可以存档、读档、看帮助、重开。存档只有一个槽。种子相同、选择相同，结果就相同。

本游戏完全离线，平台、品牌和人物都是虚构的，没有真实账号、广告或联网。"""


static func fatigue_word(value: float) -> String:
	if value < 12.0:
		return "新鲜"
	if value < 28.0:
		return "略熟"
	if value < 50.0:
		return "有点腻"
	return "观众疲了"


static func fit_word(value: float) -> String:
	if value >= 1.2:
		return "契合高"
	if value >= 1.0:
		return "契合中"
	return "契合低"


static func yuan(amount: int) -> String:
	var text := str(absi(amount))
	var grouped := ""
	while text.length() > 3:
		grouped = "," + text.substr(text.length() - 3, 3) + grouped
		text = text.substr(0, text.length() - 3)
	grouped = text + grouped
	if amount < 0:
		return "-¥%s" % grouped
	return "¥%s" % grouped


static func signed_int(amount: int) -> String:
	if amount > 0:
		return "+%d" % amount
	return str(amount)


static func signed_num(amount: float) -> String:
	var text := num(abs(amount))
	if amount > 0.0:
		return "+%s" % text
	if amount < 0.0:
		return "-%s" % text
	return "0"


static func num(amount: float) -> String:
	var rounded: float = round(abs(amount) * 1000.0) / 1000.0
	if abs(rounded - round(rounded)) < 0.0001:
		return str(int(round(rounded)))
	var text := "%0.3f" % rounded
	while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
		text = text.substr(0, text.length() - 1)
	return text


static func mult(amount: float) -> String:
	return "×%s" % num(amount)


static func absi(amount: int) -> int:
	return -amount if amount < 0 else amount
