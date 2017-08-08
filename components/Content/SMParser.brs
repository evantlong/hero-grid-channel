' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

sub init()
  print "SMParser.brs - [init]"
end sub

' Parses the response string as XML
' The parsing logic will be different for different RSS feeds
sub parseResponse()

  
  str = m.top.response.content
  cmd = m.top.cmd
  print "----- parse Response -----"
  'num = m.top.response.num

	if str = invalid return
	xml = CreateObject("roXMLElement")
  
	' Return invalid if string can't be parsed
	if not xml.Parse(str) return

	' check which parse type

	'make sure to get the UriHandler
	if m.UriHandler = invalid then 
		m.UriHandler = m.top.getParent()
	end if

	if cmd = "getSettings"
		
		settings = {
			sdadurl: xml.sdadurl.gettext()
			hdadurl : xml.sdadurl.gettext()
			advideodi : xml.advideoid.gettext()
		}

		if m.UriHandler = invalid then 
			m.UriHandler = m.top.getParent()
		end if

		m.UriHandler.contentCache.addFields(settings)

	else if cmd = "getCategories"
		
		'get the categories
		categories = xml.GetChildElements()

		print ">>>>>>>>>> Categories >>>>>>>>>>>"
		print categories
		
		'store the results in variable results[]
		results = []

		'if valid
		if categories <> invalid 

			'loop through the categories
			for each category in categories

				'addToList = 1 'variable to toggle if a category should be pushed onto the list 
					
				'result set
				result = {
					CategoryID: category@id
					Title: category.title.gettext()
					'ShortDescriptionLine1: category.title.gettext()
					ShortDescriptionLine2: category.subtitle.gettext()
					Description: category.description.gettext()
					HDPosterUrl: category.image.gettext()
					'SDPosterUrl: category.image.gettext()
				}

				'get a list of the videos
				episodes = category.videos.GetText()

				if episodes <> "0"
					result.ReleaseDate = episodes + " eps"
				end if

				if category.PosterBackgroundUrl <> invalid
					result.HDBackgroundImageUrl = category.PosterBackgroundUrl.GetText()
					result.SDBackgroundImageUrl = category.PosterBackgroundUrl.GetText()
				end if
				
				'live video 
				if category.live.GetText() = "0"
					result.StarRating = category.starrating.GetText().ToInt()
				end if

				'if the category is a live url
				if category.live.GetText() = "1"
					'set the content of the video to be bplayed
					result.ContentType = "episode"

					'set to live event
					result.Live = true

					'get the stream
					result.Streams = getStreams(category.files.GetChildElements())

					'get the format of the stream mp4/hls(m3u8)
					result.StreamFormat = result.Streams[0].format

					'if there is preroll
					if not category.preroll.IsEmpty()
						' set the preroll values

						result.PreRoll = {
							Text: m.PreRollText 
							Length: category.preroll.length.GetText()
							Streams: getStreams(category.preroll.files.GetChildElements())
							VideoID: category.preroll@id
						}

						'set the streaming format
						if not category.preroll.streamformat.IsEmpty()
							result.PreRoll.StreamFormat = category.preroll.streamformat.GetText()
						else
							result.PreRoll.StreamFormat = "mp4"
						end if

						'set HD default values
						result.PreRoll.HDBranded = false
						result.PreRoll.isHD = false

						'if one video set quality 
						if result.PreRoll.Streams.Count() = 1
							result.PreRoll.Streams[0].quality = false
						else
							' if more than one video set quality for all prerolls
							for each stream in result.PreRoll.Streams
								if stream.quality
									result.PreRoll.HDBranded = true
									result.PreRoll.isHD = true
								end if
							end for
						end if

						'set the number of prerolls
						result.PreRoll.Length = result.PreRoll.Length.toInt()

					endif

					'if the category has inchannel upgrade but inchannelupgrade is not set, then set it
					if not category.inchannelupgrade.IsEmpty() and m.InChannelUpgrade <> invalid
						result.InChannelUpgrade = true
					end if

				'will the about cateogry be showing
				else if category.about.GetText() = "1"
					result.About = true
				'will the search cateogry be showing	
				else if category.search.GetText() = "1"
					result.Search = true
				'will the audiopodcast be showgin	
				else if category.audiopodcast.GetText() = "1"
					result.AudioPodcast = true
					result.AudioPodcastUrl = category.audiopodcasturl.GetText()
				end if
				
				'skip adding the category to the queue
				'if category.live.GetText() = "1" and ((m.InChannelUpgrade = invalid OR m.InChannelUpgrade = false) and m.HideInChannelUpgradeFromPro = true)
				'	addToList = 0
				'end if	

				'add item to list if it passes all the rules
				'if(addToList = 1)
					results.Push(result)
				'end if	
			end for		
					
		end if

		m.UriHandler.contentCache.addFields(results)

	else if cmd = "getVideos"
		'create empty array
		results = []

		'create xml object
		xml = CreateObject("roXMLElement")

		'build the URL to the XML
		if params.videoID <> invalid 
			url = getURLVideo(params.videoID)
		else if params.category <> invalid 
			url = getURLCateogryVideo(params.category)
		else if params.scheduleid <> invalid 
			url = getURLScheduleVideo(params.scheduleid)
		else if params.search <> invalid 
			url = getURLSearchVideo(params.search)
		end if

		print url
          	
		'get the XML based on request
		if url <> "" and xml.Parse(getXML(url))

		'get the videos
		videos = xml.GetChildElements()

		'valid vidoes lisp 
		if videos <> invalid 

		'loop through the videos
		for each video in videos
			skip = false
			'build result object
			result = {
				VideoID: video@id
				Title: video.title.GetText()
				ShortDescriptionLine2: video.subtitle.GetText()
				Description: video.description.GetText()
				Length: video.length.GetText()
				HDPosterUrl: video.image.GetText()
				Streams: getStreams(video.files.GetChildElements()),
				Premium: video.premium.GetText()
				HDBranded: false
				isHD: false
			}

			'set the streaming format
			if not video.streamformat.IsEmpty()
				result.StreamFormat = video.streamformat.GetText()
			else
				result.StreamFormat = "mp4"
			end if


			'single 
			if result.Streams.Count() = 1
				result.Streams[0].quality = false
			else
			'multiple
			for each stream in result.Streams
				if stream.quality
					result.HDBranded = true
					result.isHD = true
				end if
			end for
			end if

			'set audio format
			if not video.surroundsound.IsEmpty()
				result.AudioFormat = "dolby-digital"
			end if
	
			'set the content type
			if m.ContentType = "video"
				result.ContentType = "episode"
			else if m.ContentType = "audio"
				result.ContentType = "audio"
			else if m.ContentType = "mix"
				'code to detect valid audio formats
			end if

			'set description
			result.ShortDescriptionLine1 = result.Title
			'set the SD poster URL to images
			result.SDPosterUrl = result.HDPosterUrl
			'set the actor as "description line 2" in Streamotor
			result.Actors = result.ShortDescriptionLine2

			'set the Interrupt toggles
			'this means a video will have precedent over the current playing
			'video because it was schedule a specific time
			if video.Interrupt <> invalid
				result.Interrupt = video.Interrupt.GetText().ToInt()
			else	
				result.Interrupt = 0 
			end if	

			'set the PlaceHolder toggle 
			if video.PlaceHolder <> invalid
				result.PlaceHolder = video.PlaceHolder.GetText().ToInt()
			else	
				result.PlaceHolder = 0 
			end if	
	
			'set the ad toggle 
			if video.Ad <> invalid
				result.Ad = video.Ad.GetText().ToInt()
			else	
				result.Ad = 0 
			end if	
	
		
			'set the start time
			if video.StartTime <> invalid
				result.StartTime = video.StartTime.GetText()
			else	
				result.StartTime = "" 
			end if	
	
			'set the user's star rating
			if not video.UserStarRating.IsEmpty() AND video.UserStarRating <> invalid
				result.UserStarRating = video.UserStarRating.GetText().ToInt()
			else
				result.UserStarRating = 0 
			end if	
	
			if not video.StarRating.IsEmpty() AND video.StarRating <> invalid
				result.StarRating = video.StarRating.GetText().ToInt()
			else	
				result.StarRating = 0  
			end if	

			'if the are pre-roll videos
			if not video.preroll.IsEmpty()

				'set the preroll object
				result.PreRoll = {
					Text: video.preroll.text.GetText()
					Length: video.preroll.length.GetText()
					Streams: getStreams(video.preroll.files.GetChildElements())
					VideoID: video.preroll@id
				}

				'set the streaming format
				if not video.preroll.streamformat.IsEmpty()
					result.PreRoll.StreamFormat = video.preroll.streamformat.GetText()
				else
					result.PreRoll.StreamFormat = "mp4"
				end if
	
				'set the HD quality
				result.PreRoll.HDBranded = false
				result.PreRoll.isHD = false
				if result.PreRoll.Streams.Count() = 1
					result.PreRoll.Streams[0].quality = false
				else
					for each stream in result.PreRoll.Streams
						if stream.quality
							result.PreRoll.HDBranded = true
							result.PreRoll.isHD = true
						end if
					end for
				end if
		
				'get the lenght of prerolls
				result.PreRoll.Length = result.PreRoll.Length.toInt()
	
				'descriptive text
				if result.PreRoll.Text = ""
					result.PreRoll.Text = m.PreRollText 
				end if

				'skip the preroll?
				if not video.preroll.skip.IsEmpty()
					result.PreRoll.Skip = true
				endif
			endif

			'if a video is set to Pay Per View
			if not video.ppv.IsEmpty()

				'if the ROKU Channel Object gives valid products then loop through
				'those products
				if m.usePPV = true AND m.RokuPaywall = true AND m.PPVProducts <> invalid
					'get each product code
					for each product in m.PPVProducts
						'if the product code matches the video id
						if product.code = result.VideoID
							'then it's valid PPV product
							result.PPVProduct = product
						end if
					end for

					'if no valid ppvproducts then skip
					if result.PPVProduct = invalid
						skip = true
					end if	

				'use WebTV for PPV, then Website must be set
				else if m.usePPV = true AND m.RokuPaywall = false AND m.Website = ""
					skip = true 
				end if

			end if
	
			'if a video is set to inchannelupgrade and the channel settins is off, then enable it
			if not video.inchannelupgrade.IsEmpty() and m.InChannelUpgrade <> invalid
				result.InChannelUpgrade = true
			end if
	
			'if skipping ppv then don't push on to the list
			if not skip
				results.Push(result)
			end if
		end for 'end the for each video

		end if	
          m.UriHandler.contentCache.addFields(results)
     end if
	end if 'end of gets

	print "---- Content Cache ----- "
	print m.UriHandler.contentCache
	print "---- Content hdadurl ----- "
	print m.UriHandler.contentCache.hdadurl

end sub


'get the video streams
function getStreams(files)

	'create array	
	streams = []
	
	'if valid files array
	if not files = invalid 
		'loop through the files
		for each file in files

			'set the stream object
			stream = {
				url: file@url
				bitrate: file@bitrate
				contentid: file@contentid
			}
			
			'set the format base on extention
			if Instr(1, file@url, "m3u8") <> 0
				stream.format = "hls"
			else if Instr(1, file@url, "mp4") <> 0
				stream.format = "mp4"
			else	
				stream.format = "hls"
			end if	

			'set the birate
			stream.bitrate = stream.bitrate.ToInt()

			'set the HD quality
			stream.quality = false
			if(file@quality = "1")
				stream.quality = true
			endif	

			
			'push stream on to the list
			streams.Push(stream)

		end for
	end if

	'return the list
	return streams

end function


