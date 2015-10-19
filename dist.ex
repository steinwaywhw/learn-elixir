require Logger 


defmodule DistTest do 
	

	defp counter_loop(outCh, n) do 
		Channel.channel_send(outCh, n, "counter out")
		counter_loop(outCh, n+1)
	end 

	def counter(n) do 
		outCh = Channel.channel()
		spawn fn -> counter_loop(outCh, n) end 
		outCh 
	end 		
	
	defp filter_loop(inCh, outCh, p) do 
		i = Channel.channel_recv(inCh, "filter in")
		if rem(i, p) != 0 do 
			Channel.channel_send(outCh, i, "filter out")
		else 
			nil 
		end 
		filter_loop(inCh, outCh, p)
	end

	def filter(p, inCh) do 
		outCh = Channel.channel()
		spawn fn -> filter_loop(inCh, outCh, p) end 
		outCh
	end 

	def sieve_loop(ch, primes) do 
		p = Channel.channel_recv ch, "sieve in"
		Channel.channel_send primes, p, "sieve out" 
		mid = filter(p, ch)
		sieve_loop(mid, primes)
	end

	def sieve() do 
		primes = Channel.channel()
		spawn fn -> sieve_loop(counter(2), primes) end 
		primes 
	end 

    defp test_loop(p) do 
    	num = Channel.channel_recv p, "test in"
    	Logger.info "********************************************* #{inspect num}"
    	IO.gets(:stdin)
    	test_loop(p)
	end

	def test() do 
		p = sieve()
		test_loop(p)
	end

end


defmodule Channel do 
	defp on_send(sender, msg) do 
		receive do 
			{:recv, receiver} -> 
				# Logger.info "[#{inspect self()}] channel got :recv request"
				send receiver, {msg}
				receive do 
					{:ack} -> send sender, {:ack}
				# after 
					# 10_000 -> Logger.info "[#{inspect self}] no ack" 
				end 
		end 
	end 

	defp on_recv(receiver) do 
		receive do 
			{:send, sender, msg} -> 
				# Logger.info "[#{inspect self()}] channel got :send request"
				send receiver, {msg}
				receive do 
					{:ack} -> send sender, {:ack}
				# after
					# 10_000 -> Logger.info "[#{inspect self}] no ack" 
				end 
		end 
	end 

	defp channel_task do 
		receive do 
			{:send, sender, msg} -> 
				# Logger.info "[#{inspect self()}] channel got :send request"
				on_send(sender, msg)
			{:recv, receiver} -> 
				# Logger.info "[#{inspect self()}] channel got :recv request"
				on_recv(receiver)
		end 
		channel_task()
	end 

	def channel do 
		spawn fn -> channel_task() end
	end

	def channel_send(channel, msg, name) do
		# Logger.info "[#{inspect self()}] [#{name}] Sending #{inspect msg}"
		send channel, {:send, self(), msg}
		receive do 
			{:ack} -> nil #Logger.info "[#{inspect self()}] [#{name}] Received ack"
		# after
			# 10_000 -> Logger.info "[#{inspect self}] no ack" 
		end
	end

	def channel_recv(channel, name) do 
		# Logger.info "[#{inspect self()}] [#{name}] Receiving"
		send channel, {:recv, self()}
		receive do 
			{msg} -> 
				# Logger.info "[#{inspect self()}] [#{name}] Received #{inspect msg}"
				send channel, {:ack}
				msg
		# after
			# 10_000 -> Logger.info "[#{inspect self}] no ack" 
		end
	end
end 

